#!/usr/bin/env bash
# Teste plugins/core/hooks/precommit-check.sh : exit 2 si typecheck/ratchet échoue,
# exit 0 pour une commande non-commit, un --dry-run ou des checks verts.
# Usage : bash scripts/test-precommit-hook.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/plugins/core/hooks/precommit-check.sh"
FAILED=0

# mkrepo <typecheck-exit> <ratchet-exit|none> : repo git avec un .ts stagé
mkrepo() {
  local d; d=$(mktemp -d)
  (
    cd "$d" && git init -q && git config user.email t@t && git config user.name t
    mkdir node_modules scripts
    printf '{"scripts":{"typecheck":"exit %s"}}' "$1" > package.json
    [ "$2" = none ] || echo "process.exit($2)" > scripts/check-file-sizes.js
    echo 'export const a = 1' > a.ts
    git add -A
  )
  echo "$d"
}

# run_case <label> <expected-exit> <repo> <command>
run_case() {
  local label="$1" expected="$2" repo="$3" cmd="$4" got
  jq -n --arg c "$cmd" --arg d "$repo" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' \
    | CLAUDE_PROJECT_DIR="$repo" bash "$HOOK" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$expected" ]; then echo "  ok   $label → exit $expected"
  else echo "  FAIL $label : attendu $expected, obtenu $got"; FAILED=$((FAILED + 1)); fi
  rm -rf "$repo"
}

command -v jq >/dev/null || { echo "jq requis"; exit 1; }
echo "precommit-check hook"
run_case "typecheck KO bloque"        2 "$(mkrepo 1 none)" 'git commit -m x'
run_case "typecheck OK passe"         0 "$(mkrepo 0 none)" 'git commit -m x'
run_case "ratchet KO bloque"          2 "$(mkrepo 0 1)"    'git commit -m x'
run_case "ratchet OK passe"           0 "$(mkrepo 0 0)"    'git commit -m x'
run_case "chaîne && git commit bloque" 2 "$(mkrepo 1 none)" 'git add -A && git commit -m x'
run_case "option -C bloque"           2 "$(mkrepo 1 none)" 'git -C . commit -m x'
run_case "commande non-commit ignorée" 0 "$(mkrepo 1 none)" 'git status'
run_case "commit-tree ignoré"         0 "$(mkrepo 1 none)" 'git commit-tree HEAD'
run_case "--dry-run ignoré"           0 "$(mkrepo 1 none)" 'git commit --dry-run'

if [ "$FAILED" -gt 0 ]; then echo "$FAILED cas en échec"; exit 1; fi
echo "tous les cas passent"
