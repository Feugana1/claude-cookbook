#!/usr/bin/env bash
# Claude Code hook — PreToolUse Bash
#
# Avant un vrai `git commit`, lance des checks rapides et bloque (exit 2) si l'un échoue :
#   1. typecheck, si des .ts/.tsx sont concernés et que le projet a un script
#      `typecheck` / `type-check` (npm, pnpm, yarn ou bun détecté par lockfile)
#   2. ratchet de taille de fichiers, si `scripts/check-file-sizes.js` existe
# Puis suggère (stderr, exit 0) la review du reviewer final pour un diff non trivial.
#
# Aucun check n'est inventé : sans script correspondant, l'étape est sautée.
# Bypass volontaire impossible depuis le hook ; pour le désactiver, retirer son
# entrée de hooks.json (plugin) ou de .claude/settings.json (bootstrap).

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "[hook:precommit] jq introuvable : checks pré-commit désactivés. Installer jq." >&2
  exit 0
fi

input=$(cat 2>/dev/null || echo '{}')
[ "$(printf '%s' "$input" | jq -r '.tool_name // empty')" = "Bash" ] || exit 0
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')

# Un vrai `git commit` : en début de commande ou après ; && || | ( , avec options
# globales éventuelles (-C dir, -c k=v). Exclut `git commit-tree`, --dry-run, --help.
re='(^|[;&|(][[:space:]]*)git([[:space:]]+(-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--no-pager))*[[:space:]]+commit([[:space:]]|$)'
[[ $cmd =~ $re ]] || exit 0
case "$cmd" in *--dry-run*|*--help*) exit 0 ;; esac

project="${CLAUDE_PROJECT_DIR:-$(printf '%s' "$input" | jq -r '.cwd // empty')}"
cd "${project:-.}" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Fichiers concernés : l'index ; si la commande stage elle-même (git add, commit -a),
# inclure aussi les changements suivis non encore stagés.
files=$(git diff --cached --name-only 2>/dev/null || true)
if [[ $cmd =~ git[[:space:]]+add ]] || [[ $cmd =~ commit[[:space:]]+(.*[[:space:]])?-[a-zA-Z]*a ]]; then
  files=$(printf '%s\n%s\n' "$files" "$(git diff --name-only HEAD 2>/dev/null || true)" | sort -u)
fi
[ -n "$(printf '%s' "$files" | tr -d '[:space:]')" ] || exit 0

pm=npm
[ -f pnpm-lock.yaml ] && pm=pnpm
[ -f yarn.lock ] && pm=yarn
{ [ -f bun.lockb ] || [ -f bun.lock ]; } && pm=bun

has_script() { [ -f package.json ] && jq -e --arg s "$1" '.scripts[$s] // empty' package.json >/dev/null 2>&1; }

# 1. Typecheck
if printf '%s\n' "$files" | grep -qE '\.(ts|tsx)$'; then
  script=""
  has_script typecheck && script=typecheck
  [ -z "$script" ] && has_script type-check && script=type-check
  if [ -z "$script" ]; then
    echo "[hook:precommit] Typecheck sauté : pas de script 'typecheck' dans package.json." >&2
  elif [ ! -d node_modules ]; then
    echo "[hook:precommit] Typecheck sauté : node_modules absent (installer les dépendances)." >&2
  else
    echo "[hook:precommit] Typecheck ($pm run $script)…" >&2
    if ! out=$("$pm" run --silent "$script" 2>&1); then
      printf '%s\n' "$out" | tail -20 >&2
      echo "[hook:precommit] BLOQUÉ — le typecheck échoue. Corriger les erreurs, re-stager, nouveau commit." >&2
      exit 2
    fi
  fi
fi

# 2. Ratchet de taille de fichiers (fourni par un pack de stack)
if [ -f scripts/check-file-sizes.js ] && printf '%s\n' "$files" | grep -qvE '\.(md|txt|json|ya?ml)$'; then
  echo "[hook:precommit] Ratchet de taille de fichiers…" >&2
  if ! out=$(node scripts/check-file-sizes.js 2>&1); then
    printf '%s\n' "$out" | tail -30 >&2
    echo "[hook:precommit] BLOQUÉ — ratchet de taille en échec. Splitter le fichier ou régénérer la baseline après un split légitime." >&2
    exit 2
  fi
fi

# 3. Suggestion de review pour un diff non trivial
nb_files=$(printf '%s\n' "$files" | grep -c . || true)
shortstat=$(git diff --cached --shortstat 2>/dev/null || true)
ins=$(printf '%s' "$shortstat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || true)
del=$(printf '%s' "$shortstat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || true)
total=$(( ${ins:-0} + ${del:-0} ))

significant=0
{ [ "$nb_files" -ge 2 ] || [ "$total" -ge 50 ]; } && significant=1
printf '%s\n' "$files" | grep -qiE '(^|/)(migrations?|routes?|middleware)(/|\.|$)' && significant=1

if [ "$significant" = "1" ]; then
  reviewer="reviewer"
  [ -n "$(find .claude/agents -name 'code-reviewer.md' 2>/dev/null | head -1)" ] && reviewer="code-reviewer"
  echo "[hook:precommit] Diff non trivial ($nb_files fichiers, ~$total lignes) : invoquer le subagent '$reviewer' avant de commiter (verdict SHIP / NEEDS CHANGES / REJECT)." >&2
fi

exit 0
