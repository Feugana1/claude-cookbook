#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 6. SQL injection scan ──────────────────────────────────────────────────
step 6 "SQL injection scan" 1 "A03 Injection"
SQL_ISSUES=$(grep -rn 'rawQuery\|whereRaw\|havingRaw' app/ --include="*.ts" 2>/dev/null \
  | grep '\${' || true)
if [ -z "$SQL_ISSUES" ]; then
  pass "No string interpolation in raw SQL"
else
  COUNT=$(echo "$SQL_ISSUES" | wc -l | tr -d ' \r')
  fail "$COUNT raw SQL with \${} — use ? parameterized bindings"
  echo "$SQL_ISSUES" | head -5 | while IFS= read -r line; do echo "    $line"; done
fi
