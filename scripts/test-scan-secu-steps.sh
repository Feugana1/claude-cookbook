#!/usr/bin/env bash
# Teste les steps grep de scan-secu.d/ sur des fixtures : un fichier vulnérable
# doit être détecté (FAIL ou WARN), un fichier sain doit passer.
# Usage : bash scripts/test-scan-secu-steps.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STEPS="$ROOT/plugins/core/scripts/scan-secu.d"
OUT=""
step() { :; }
pass() { OUT="PASS"; }
fail() { OUT="FAIL"; }
warn() { OUT="WARN"; }
skip() { OUT="SKIP"; }

FAILED=0
# run_case <step-file> <expected> <chemin-fixture> <contenu>
run_case() {
  local step_file="$1" expected="$2" rel="$3" content="$4" d
  d=$(mktemp -d)
  mkdir -p "$d/$(dirname "$rel")"
  printf '%s\n' "$content" > "$d/$rel"
  OUT=""
  # shellcheck disable=SC1090
  (cd "$d" && source "$STEPS/$step_file" >/dev/null 2>&1; echo "$OUT") > "$d/.out"
  local got; got=$(tail -1 "$d/.out")
  if [ "$got" = "$expected" ]; then
    echo "  ok   $step_file → $expected"
  else
    echo "  FAIL $step_file : attendu $expected, obtenu '${got:-rien}'"; FAILED=$((FAILED + 1))
  fi
  rm -rf "$d"
}

echo "scan-secu steps"
run_case step-04-crypto-scan.sh FAIL app/services/token.ts 'const t = Math.random().toString(36)'
run_case step-04-crypto-scan.sh PASS app/services/token.ts 'const t = randomBytes(16).toString("hex")'

run_case step-06-sql-injection-scan.sh FAIL app/services/q.ts 'db.rawQuery(`select * from users where id = ${id}`)'
run_case step-06-sql-injection-scan.sh PASS app/services/q.ts 'db.rawQuery("select * from users where id = ?", [id])'

run_case step-08-ssrf-scan.sh WARN app/services/http.ts 'const base = "http://127.0.0.1:9000"'
run_case step-08-ssrf-scan.sh PASS app/services/http.ts 'const base = env.get("API_URL")'
run_case step-08-ssrf-scan.sh PASS app/services/http.ts '// dev only: http://localhost:3000'

run_case step-12-redos-scan.sh WARN app/controllers/c.ts 'const re = new RegExp(request.input("q"))'
run_case step-12-redos-scan.sh PASS app/controllers/c.ts 'const re = new RegExp("^a+$")'

run_case step-13-prototype-pollution.sh WARN app/controllers/c.ts 'Object.assign(user, request.all())'
run_case step-13-prototype-pollution.sh PASS app/controllers/c.ts 'const x = pick(request.all(), ["name"])'

run_case step-25-password-reset-ttl.sh FAIL app/services/reset.ts \
  'const k = TOKEN_TYPES.PASSWORD_RESET; token.expiresAt = DateTime.now().plus({ hours: 24 })'
run_case step-25-password-reset-ttl.sh PASS app/services/reset.ts \
  'const k = TOKEN_TYPES.PASSWORD_RESET; token.expiresAt = DateTime.now().plus({ minutes: 30 })'

if [ "$FAILED" -gt 0 ]; then echo "$FAILED cas en échec"; exit 1; fi
echo "tous les cas passent"
