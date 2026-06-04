#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 12. ReDoS scan (catastrophic backtracking regex) ────────────────────────
step 12 "ReDoS scan (regex denial of service)" 1 "A03 Injection"
REDOS_ISSUES=$(grep -rn 'new RegExp\|\.match(\|\.replace(\|\.split(' app/controllers/ app/services/ app/validators/ --include="*.ts" 2>/dev/null \
  | grep -v 'node_modules\|\.spec\.\|\.test\.' || true)
# Lines annotated with "audited" OR "redos-safe" are treated as reviewed and skipped.
REDOS_DANGEROUS=$(echo "$REDOS_ISSUES" | grep -i 'request\.\|input\.\|params\.\|body\.\|query\.' \
  | grep -v 'audited\|redos-safe' || true)
if [ -z "$REDOS_DANGEROUS" ]; then
  pass "No user-input regex patterns detected"
else
  COUNT=$(echo "$REDOS_DANGEROUS" | wc -l | tr -d ' \r')
  warn "$COUNT regex on user input — verify no catastrophic backtracking"
  echo "$REDOS_DANGEROUS" | head -5 | while IFS= read -r line; do echo "    $line"; done
fi
