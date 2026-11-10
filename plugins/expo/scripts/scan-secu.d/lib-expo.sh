#!/usr/bin/env bash
# Helpers partagés par les steps scan-secu du pack expo (sourcés par chaque step).
# Ce fichier n'est pas un step : son nom ne commence pas par `step-`, l'orchestrateur
# ne le lance pas et il n'entre pas dans le total. Définitions idempotentes.

# Projet Expo = package.json qui dépend de `expo`.
expo_is_project() {
  [ -f package.json ] && grep -qE '"expo"[[:space:]]*:' package.json
}

# Garde une liste (stdin) ; en --diff, seulement les fichiers modifiés.
expo_changed_filter() {
  local f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ "${MODE:-full}" != "diff" ] || printf '%s\n' "${CHANGED_FILES:-}" | grep -qxF "$f"; then
      printf '%s\n' "$f"
    fi
  done
  return 0
}

# Fichiers de config Expo / EAS présents à la racine (filtrés en --diff).
expo_config_files() {
  local f
  for f in app.json app.config.ts app.config.js app.config.mjs app.config.cjs eas.json; do
    if [ -f "$f" ]; then printf '%s\n' "$f"; fi
  done | expo_changed_filter
  return 0
}

# Sources JS/TS de l'app, hors dépendances, natif généré, build, tests et configs d'outils.
# En --diff : fichiers modifiés seulement.
expo_sources() {
  local list f
  if [ "${MODE:-full}" = "diff" ]; then
    list="${CHANGED_FILES:-}"
  elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    list=$(git ls-files --cached --others --exclude-standard 2>/dev/null || true)
  else
    list=$(find . -type f -not -path '*/node_modules/*' 2>/dev/null | sed 's|^\./||' || true)
  fi
  printf '%s\n' "$list" \
    | grep -E '\.(ts|tsx|js|jsx|mjs|cjs)$' \
    | grep -vE '(^|/)(node_modules|ios|android|dist|web-build|build|coverage|\.expo)/' \
    | grep -vE '\.test\.|\.spec\.|__tests__/|__mocks__/|\.d\.ts$' \
    | grep -vE '(^|/)(app|metro|babel|eslint|jest|tailwind|prettier)\.config\.' \
    | while IFS= read -r f; do
        if [ -f "$f" ]; then printf '%s\n' "$f"; fi
      done || true
  return 0
}

# grep ERE sur les sources, hors lignes annotées `canonical-skip:`.
# Usage : expo_grep [-i] '<regex>'   → lignes "fichier:ligne:contenu"
expo_grep() {
  local files
  files=$(expo_sources)
  [ -n "$files" ] || return 0
  printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 grep -nHE "$@" 2>/dev/null | grep -v 'canonical-skip:' || true
}

# Fichiers sources qui matchent (un par ligne). Usage : expo_files_matching [-i] '<regex>'
expo_files_matching() {
  local files
  files=$(expo_sources)
  [ -n "$files" ] || return 0
  printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 grep -lE "$@" 2>/dev/null || true
}

# Nombre de lignes non vides d'un résultat.
expo_count() { printf '%s' "$1" | grep -c . || true; }

# Affiche les N premières lignes d'un résultat, indentées et tronquées.
expo_show() {
  printf '%s\n' "$1" | grep . | head -"${2:-5}" | cut -c1-180 | while IFS= read -r l; do echo "    $l"; done
}

# Lance une commande avec un délai maximal en secondes (portable : perl, présent sur macOS et Linux).
# Code 142 = délai dépassé.
expo_with_timeout() {
  local secs="$1"; shift
  perl -e 'alarm shift; exec @ARGV or exit 127' "$secs" "$@"
}

# Vrai si une sortie de commande ressemble à une erreur réseau (mode hors-ligne).
expo_is_network_error() {
  printf '%s' "$1" | grep -qiE 'ENOTFOUND|EAI_AGAIN|ECONNREFUSED|ECONNRESET|ETIMEDOUT|fetch failed|network|offline|getaddrinfo|socket hang up'
}
