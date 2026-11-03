#!/usr/bin/env bash
# Claude Code hook — PostToolUse Edit/Write/MultiEdit
#
# Lit le JSON envoyé par Claude Code sur stdin, identifie le path touché,
# grep les anti-patterns P0 du projet et :
#   - exit 2 (BLOCK) si un P0 grepable est détecté
#   - écrit en stderr les suggestions d'experts (couches 1→3)
#   - exit 0 sinon (PASS silencieux)
#
# Source de vérité : docs/claude-config/experts.md
# Conventions de scope : ce fichier est la source du mapping path→expert (voir docs/claude-config/experts.md pour les couches)
#
# Note : les "hints" stderr sont lus par Claude qui les traite comme system
# messages. Le hook ne lance PAS de subagent directement (anti-pattern CC).

set -euo pipefail

# Lecture stdin Claude Code (JSON)
input=$(cat 2>/dev/null || echo '{}')

# Tools concernés
tool=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
case "$tool" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

# Path du fichier touché
file=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
[ -z "$file" ] && exit 0
[ -f "$file" ] || exit 0

# Path relatif pour matchers (au cas où Claude envoie absolu)
rel="${file#$(pwd)/}"

# ---------- Front / Edge / CSS / JS ----------
case "$rel" in
  *.edge|resources/css/*|resources/js/*)
    # P0 grep — bloque si match. Exclut la forme canonique :
    # `<script type="application/json">{{{ JSON.stringify(...) }}}</script>` est le pattern
    # officiel pour injecter du JSON sans HTML-escape (utilisé welcome.edge, layout/auth.edge,
    # _share_modal.edge, etc.). On ne bloque QUE les `{{{ JSON.stringify` hors d'un tel script.
    if grep -nE '\{\{\{[[:space:]]*JSON\.stringify' "$file" 2>/dev/null \
      | grep -v 'type="application/json"' \
      | grep -v "type='application/json'" \
      | grep -q .; then
      echo "[hook:edge-P0] BLOCKED — '{{{ JSON.stringify }}}' hors <script type=\"application/json\"> dans $rel. Cf CLAUDE.md §13 + anti-patterns-adonisjs.md. Invoke 'edge-anti-patterns' subagent." >&2
      exit 2
    fi
    if grep -nE '@(click|input|blur|change|dragover|drop)[^"]*=' "$file" >/dev/null 2>&1; then
      # Seulement bloquant si fichier partial @include'd (commence par _)
      base=$(basename "$rel")
      if [[ "$base" =~ ^_.+\.edge$ ]]; then
        echo "[hook:edge-P0] BLOCKED — directive Alpine \"@click/@input/etc.\" dans un partial $rel — Edge interprète @ comme directive. Utiliser 'x-on:click' etc. CLAUDE.md §13. Invoke 'edge-anti-patterns' subagent." >&2
        exit 2
      fi
    fi
    if grep -nE '^[[:space:]]*[^[:space:]<].*@svg\(' "$file" >/dev/null 2>&1; then
      # @svg mid-line — output littéral en prod
      echo "[hook:edge-P1] WARNING — @svg() mid-ligne dans $rel — edge-iconify ne déclenche QUE début-de-ligne. Casser sur sa propre ligne. CLAUDE.md §13. Invoke 'edge-anti-patterns' subagent." >&2
    fi
    # Hints couche 4 (linter fast-pass)
    case "$rel" in
      *.edge) echo "[hook:hint] edge-anti-patterns — linter rapide patterns P0/P1 Edge/Alpine (couche 4)." >&2 ;;
    esac
    # Project-specific front hints — extension point.
    # Un projet UI-heavy peut ajouter un front-curator ou équivalent via
    # .claude/hooks/dispatch-expert.local.sh (sourcé si présent).
    if [ -f .claude/hooks/dispatch-expert.local.sh ]; then
      # shellcheck disable=SC1091
      source .claude/hooks/dispatch-expert.local.sh
    fi
    exit 0
    ;;
esac

# ---------- Lang JSON ----------
case "$rel" in
  resources/lang/*/*.json)
    # ICU vs Mustache — P0
    if grep -nE '\{\{[a-zA-Z_][a-zA-Z0-9_]*\}\}' "$file" >/dev/null 2>&1; then
      echo "[hook:i18n-P0] BLOCKED — syntax Mustache '{{var}}' dans $rel — ICU MessageFormat attendu '{var}'. Crash MALFORMED_ARGUMENT au runtime. CLAUDE.md §13." >&2
      exit 2
    fi
    exit 0
    ;;
esac

# ---------- Backend TS ----------
case "$rel" in
  app/controllers/*|app/services/*|app/middleware/*|app/validators/*|start/routes.ts)
    # P0 grep — sécurité
    if grep -nE 'auth\.user\.id[^_a-zA-Z0-9]' "$file" >/dev/null 2>&1; then
      echo "[hook:sec-P0] BLOCKED — 'auth.user.id' dans $rel — utiliser 'effectiveUserId' (middleware team). CLAUDE.md §11 §12, security-multitenant.md. Invoke 'security-multitenant' subagent." >&2
      exit 2
    fi
    if grep -nE 'drive\.use\(' "$file" >/dev/null 2>&1 && [[ "$rel" != *storage_service* ]]; then
      echo "[hook:sec-P0] BLOCKED — 'drive.use()' direct dans $rel — utiliser 'StorageService.upload/delete/getStream/getSignedUrl'. CLAUDE.md §12, storage-s3.md, scan-secu.sh 22B." >&2
      exit 2
    fi
    if grep -nE '\.catch\(\(\)[[:space:]]*=>[[:space:]]*\{\}\)' "$file" >/dev/null 2>&1; then
      echo "[hook:sec-P0] BLOCKED — '.catch(() => {})' dans $rel — utiliser 'import { swallow } from \"#helpers/swallow\"' puis '.catch(swallow(\"op_name\"))'. CLAUDE.md §13, scan-secu.sh 22F." >&2
      exit 2
    fi
    if grep -nE '\.raw\(.*\$\{' "$file" >/dev/null 2>&1 || grep -nE 'rawQuery\(.*\$\{' "$file" >/dev/null 2>&1; then
      echo "[hook:sec-P0] BLOCKED — raw SQL avec template literal \${} dans $rel — utiliser paramètres '?'. CLAUDE.md §10, scan-secu.sh step 06." >&2
      exit 2
    fi
    # Auth User.email case-sensitivity — feedback memory feedback_email_query_case_insensitive
    # Postgres = est case-sensitive, iOS auto-cap les premiers char → silent miss + flash success trompeur
    if [[ "$rel" == app/controllers/auth/* ]] && grep -nE "\.where\(['\"]email['\"]," "$file" >/dev/null 2>&1; then
      echo "[hook:sec-P0] BLOCKED — '.where(\"email\", ...)' dans $rel — Postgres = case-sensitive + iOS auto-cap. Utiliser '.whereILike(\"email\", email.trim())'. Régression magic-link 2026-06-05, cf MEMORY.md feedback_email_query_case_insensitive." >&2
      exit 2
    fi
    # Lucid table-prefix camelCase — feedback memory feedback_lucid_table_prefix_camelcase
    # `.where('table.userId', x)` ne convertit PAS le préfixe → crash "column does not exist"
    if grep -nE "\.(where|orWhere|andWhere|whereIn|whereNotIn)\(['\"][a-z_]+\.[a-z][a-zA-Z0-9_]*[A-Z][a-zA-Z0-9_]*['\"]" "$file" >/dev/null 2>&1; then
      echo "[hook:sec-P0] BLOCKED — '.where(\"table.camelCase\", …)' dans $rel — la SnakeCaseNamingStrategy ne convertit PAS quand préfixe table. présent. Écrire snake_case explicite: '.where(\"table.snake_case\", …)'. 3 crashes prod 2026-06-03, cf MEMORY.md feedback_lucid_table_prefix_camelcase + scan-secu.sh step 32." >&2
      exit 2
    fi
    # Layered hints — Architects → cross-cutting → domain
    echo "[hook:hint] back-architect — conventions AdonisJS (300/400L, naming, validators, helpers) (couche 1 architect)." >&2
    echo "[hook:hint] security-multitenant — effectiveUserId, IDOR, CSRF, soft-delete (couche 2 cross-cutting)." >&2
    case "$rel" in
      app/services/*|app/models/*)
        echo "[hook:hint] data-access-reviewer — preload vs load, raw SQL, pool, TTL Redis (couche 2 fast-pass haiku)." >&2 ;;
    esac
    # Project-specific domain hints — extension point.
    # Un projet peut créer .claude/hooks/dispatch-expert.local.sh (sourcé si présent)
    # pour ajouter ses propres experts domain (compta / marketplace / public / etc.).
    if [ -f .claude/hooks/dispatch-expert.local.sh ]; then
      # shellcheck disable=SC1091
      source .claude/hooks/dispatch-expert.local.sh
    fi
    exit 0
    ;;
esac

# ---------- Models ----------
case "$rel" in
  app/models/*.ts)
    echo "[hook:hint] back-architect — conventions naming, columns/extras (couche 1)." >&2
    echo "[hook:hint] data-access-reviewer — preload, JSONB prepare/consume helpers (couche 2)." >&2
    if [ -f .claude/hooks/dispatch-expert.local.sh ]; then
      # shellcheck disable=SC1091
      source .claude/hooks/dispatch-expert.local.sh
    fi
    exit 0
    ;;
esac

# ---------- Migrations ----------
case "$rel" in
  database/migrations/*.ts)
    echo "[hook:hint] migration-reviewer — IF NOT EXISTS, DEFAULT NOT NULL, JSONB documenté, ALTER CONSTRAINT enum, prepare/consume (couche 2 cross-cutting)." >&2
    if [ -f .claude/hooks/dispatch-expert.local.sh ]; then
      # shellcheck disable=SC1091
      source .claude/hooks/dispatch-expert.local.sh
    fi
    exit 0
    ;;
esac

# ---------- Default : pas de hint ----------
exit 0
