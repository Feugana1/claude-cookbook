#!/usr/bin/env bash
# Claude Code hook — PostToolUse Edit|Write|MultiEdit (pack adonisjs)
#
# Lit le JSON de l'événement sur stdin, grep les anti-patterns P0 grepables du
# fichier modifié, puis :
#   - exit 2 + stderr : un P0 est détecté. Claude reçoit le message et doit
#     corriger (l'édition est déjà faite : le hook ne l'annule pas).
#   - exit 0 + JSON `additionalContext` : conseils d'experts à invoquer.
#   - exit 0 silencieux sinon.
#
# Le hook ne lance JAMAIS de subagent : il bloque les P0 et suggère les experts.
#
# Extension projet : si `.claude/hooks/dispatch-expert.local.sh` existe, il est
# sourcé après les règles et peut appeler `hint "texte"` pour ajouter ses
# propres conseils (experts domain du projet).
#
# Source de vérité des règles : docs/anti-patterns-adonisjs.md.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "[hook:dispatch] jq introuvable : les contrôles P0 sont désactivés. Installer jq (brew install jq)." >&2
  exit 0
fi

input=$(cat 2>/dev/null || echo '{}')
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')
case "$tool" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
[ -n "$file" ] && [ -f "$file" ] || exit 0

project="${CLAUDE_PROJECT_DIR:-$(printf '%s' "$input" | jq -r '.cwd // empty')}"
project="${project:-$(pwd)}"
rel="${file#"$project"/}"

HINTS=()
hint() { HINTS+=("$1"); }
block() { echo "[hook:$1] P0 — $2 Corriger avant de continuer." >&2; exit 2; }

emit_and_exit() {
  local local_hook="$project/.claude/hooks/dispatch-expert.local.sh"
  # shellcheck disable=SC1090
  [ -f "$local_hook" ] && source "$local_hook"
  if [ "${#HINTS[@]}" -gt 0 ]; then
    jq -n --arg c "$(printf '%s\n' "${HINTS[@]}")" \
      '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
  fi
  exit 0
}

has() { grep -nE "$1" "$file" >/dev/null 2>&1; }

case "$rel" in
  # ---------- Templates Edge / CSS / JS ----------
  *.edge|resources/css/*|resources/js/*)
    # `{{{ JSON.stringify }}}` n'est légitime que dans <script type="application/json">.
    if grep -nE '\{\{\{[[:space:]]*JSON\.stringify' "$file" 2>/dev/null \
      | grep -v "type=[\"']application/json[\"']" | grep -q .; then
      block "edge-P0" "'{{{ JSON.stringify }}}' hors <script type=\"application/json\"> dans $rel. Invoquer 'edge-anti-patterns'."
    fi
    # Directive Alpine @click/@input… dans un partial (_*.edge) : Edge interprète @ comme directive.
    if has '@(click|input|blur|change|dragover|drop)[^"]*=' && [[ "$(basename "$rel")" =~ ^_.+\.edge$ ]]; then
      block "edge-P0" "directive Alpine '@click' (ou similaire) dans le partial $rel : utiliser 'x-on:click'. Invoquer 'edge-anti-patterns'."
    fi
    if has '^[[:space:]]*[^[:space:]<].*@svg\('; then
      hint "[edge-P1] @svg() en milieu de ligne dans $rel : edge-iconify ne se déclenche qu'en début de ligne, le placer sur sa propre ligne."
    fi
    case "$rel" in *.edge) hint "[edge] Invoquer 'edge-anti-patterns' (linter rapide Edge/Alpine) sur $rel." ;; esac
    ;;

  # ---------- i18n ----------
  resources/lang/*/*.json)
    if has '\{\{[a-zA-Z_][a-zA-Z0-9_]*\}\}'; then
      block "i18n-P0" "syntaxe Mustache '{{var}}' dans $rel : ICU MessageFormat attendu ('{var}'), sinon crash MALFORMED_ARGUMENT au runtime."
    fi
    ;;

  # ---------- Backend ----------
  app/controllers/*|app/services/*|app/middleware/*|app/validators/*|start/routes.ts)
    has 'auth\.user\.id([^_a-zA-Z0-9]|$)' \
      && block "sec-P0" "'auth.user.id' dans $rel : utiliser 'effectiveUserId' (middleware team). Invoquer 'security-multitenant'."
    has 'drive\.use\(' && [[ "$rel" != *storage* ]] \
      && block "sec-P0" "'drive.use()' direct dans $rel : passer par le module storage du projet."
    has '\.catch\(\(\)[[:space:]]*=>[[:space:]]*\{\}\)' \
      && block "sec-P0" "'.catch(() => {})' dans $rel : utiliser le helper 'swallow' (.catch(swallow(\"op_name\")))."
    has '\.raw\(.*\$\{|rawQuery\(.*\$\{' \
      && block "sec-P0" "raw SQL avec template literal \${} dans $rel : utiliser des paramètres '?'."
    # Lucid : le préfixe de table désactive la conversion camelCase -> snake_case.
    has "\.(where|orWhere|andWhere|whereIn|whereNotIn)\(['\"][a-z_]+\.[a-z][a-zA-Z0-9_]*[A-Z][a-zA-Z0-9_]*['\"]" \
      && block "sec-P0" "'.where(\"table.camelCase\", …)' dans $rel : la SnakeCaseNamingStrategy ne convertit pas quand un préfixe de table est présent. Écrire la colonne en snake_case."
    if [[ "$rel" == app/controllers/auth/* ]] && has "\.where\(['\"]email['\"],"; then
      hint "[sec-P1] $rel : Postgres compare 'email' en respectant la casse (les claviers mobiles capitalisent). Préférer '.whereILike(\"email\", email.trim())'."
    fi
    hint "[arch] Invoquer 'back-architect' (conventions, tailles, validators) et 'security-multitenant' (effectiveUserId, IDOR, CSRF) sur $rel."
    case "$rel" in app/services/*) hint "[data] Invoquer 'data-access-reviewer' (preload, raw SQL, pool, TTL cache) sur $rel." ;; esac
    ;;

  # ---------- Models ----------
  app/models/*.ts)
    hint "[arch] Invoquer 'back-architect' (conventions) et 'data-access-reviewer' (preload, prepare/consume JSONB) sur $rel."
    ;;

  # ---------- Migrations ----------
  database/migrations/*.ts)
    hint "[data] Invoquer 'migration-reviewer' (idempotence, DEFAULT sur NOT NULL, JSONB, ALTER CONSTRAINT enum) sur $rel."
    ;;
esac

emit_and_exit
