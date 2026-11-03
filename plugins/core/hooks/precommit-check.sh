#!/usr/bin/env bash
# Claude Code hook — PreToolUse Bash
#
# Intercepte les appels Bash. Si la commande contient `git commit` (hors
# annulation, --amend interactif, etc.), lance des checks rapides avant
# d'autoriser le commit :
#   - npm run typecheck (tsc --noEmit)
#   - node scripts/check-file-sizes.js (ratchet baseline)
#
# Source de vérité : CLAUDE.md §1 (commandes courantes), §14 (limites taille),
# scan-secu.sh étape 19 (file size ratchet).
#
# Comportement :
#   - exit 2 (BLOCK) si typecheck ou check:sizes fail → message en stderr
#   - exit 0 (PASS) sinon
#
# Bypass volontaire : impossible via le hook (volontaire). Si vraiment
# nécessaire, retirer temporairement l'entrée hooks dans settings.json.

set -euo pipefail

input=$(cat 2>/dev/null || echo '{}')
tool=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
[ "$tool" = "Bash" ] || exit 0

cmd=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# Filtre : ne déclencher QUE sur git commit "vraiment commit"
case "$cmd" in
  *git\ commit*)
    # Exclure les variantes qui ne créent pas réellement de commit
    case "$cmd" in
      *--dry-run*|*--help*|*-h\ *|*--show-current-patch*) exit 0 ;;
    esac
    ;;
  *) exit 0 ;;
esac

# Détecter quels paths sont staged — checks conditionnels
# Évite faux positifs sur commits doc/config qui ne touchent pas le code
staged=$(git diff --cached --name-only 2>/dev/null || echo "")

has_ts_or_edge=0
has_app_or_views=0
echo "$staged" | while IFS= read -r f; do
  case "$f" in
    *.ts) echo "ts"; break ;;
  esac
done | grep -q ts && has_ts_or_edge=1 || true
if echo "$staged" | grep -qE '^(app/|resources/views/)' 2>/dev/null; then
  has_app_or_views=1
fi

echo "[hook:precommit] Staged paths analysis : ts=$has_ts_or_edge app|views=$has_app_or_views" >&2

# 1. Typecheck — conditionnel sur la présence de .ts staged
if [ "$has_ts_or_edge" = "1" ] || echo "$staged" | grep -qE '\.(ts|tsx)$' 2>/dev/null; then
  # Guard: skip if node_modules is absent (remote execution env without full install)
  if [ ! -f node_modules/.bin/tsc ]; then
    echo "[hook:precommit] Typecheck skipped — node_modules not installed (remote env). Run locally before merge." >&2
  else
    echo "[hook:precommit] Running typecheck…" >&2
    if ! npm run --silent typecheck 2>&1 | tail -20 >&2; then
      echo "[hook:precommit] BLOCKED — typecheck failed. Fix TS errors before commit. Cf CLAUDE.md §1." >&2
      exit 2
    fi
  fi
else
  echo "[hook:precommit] Typecheck skipped (no .ts staged)." >&2
fi

# 2. File size ratchet — conditionnel sur la présence de fichiers app/* ou resources/views/* staged
# Évite de bloquer les commits doc/config sur de la dette préexistante non touchée
if [ "$has_app_or_views" = "1" ]; then
  if [ -f scripts/check-file-sizes.js ]; then
    echo "[hook:precommit] Running file-size ratchet…" >&2
    if ! node scripts/check-file-sizes.js 2>&1 | tail -30 >&2; then
      echo "[hook:precommit] BLOCKED — file-size ratchet failed. Splitter ou regénérer baseline. Cf CLAUDE.md §14, scan-secu.sh step 19." >&2
      exit 2
    fi
  fi
else
  echo "[hook:precommit] File-size ratchet skipped (no app/ or resources/views/ staged)." >&2
fi

# 3. Suggestion code-reviewer si diff non-trivial
# Métrique : ≥ 2 fichiers OU ≥ 50 lignes OU touche app|resources/views|database/migrations|start/routes.ts
nb_files=$(echo "$staged" | grep -c . 2>/dev/null || echo 0)
nb_lines=$(git diff --cached --shortstat 2>/dev/null | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
nb_lines=${nb_lines:-0}
nb_lines_del=$(git diff --cached --shortstat 2>/dev/null | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)
nb_lines_del=${nb_lines_del:-0}
total_lines=$((nb_lines + nb_lines_del))

is_significant=0
if [ "$nb_files" -ge 2 ] || [ "$total_lines" -ge 50 ] || [ "$has_app_or_views" = "1" ]; then
  is_significant=1
fi
# Touche migrations/routes/middleware ?
if echo "$staged" | grep -qE '^(database/migrations/|start/routes\.ts|app/middleware/)' 2>/dev/null; then
  is_significant=1
fi

if [ "$is_significant" = "1" ]; then
  echo "[hook:precommit] Hint: invoke 'code-reviewer' subagent for senior PR review (diff: $nb_files files, +$nb_lines/-$nb_lines_del lines). Output verdict SHIP / NEEDS CHANGES / REJECT before commit." >&2
fi

echo "[hook:precommit] OK — checks passed (or skipped on irrelevant scope)." >&2
exit 0
