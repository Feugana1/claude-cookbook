#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 11. Code duplication (jscpd) ────────────────────────────────────────────
step 11 "Code duplication scan" 3 "Code quality"
if npx jscpd --version > /dev/null 2>&1; then
  DUP_OUT=$(npx jscpd app/ --min-lines 15 --min-tokens 80 --threshold 10 --silent 2>&1 || true)
  if echo "$DUP_OUT" | grep -q "Interrupted"; then
    fail "Code duplication > 10% — run 'npx jscpd app/ --min-lines 15' for details"
  else
    DUP_PCT=$(echo "$DUP_OUT" | grep -o '[0-9.]*%' | tail -1 || echo "0%")
    if [ -z "$DUP_PCT" ]; then DUP_PCT="0%"; fi
    pass "Duplication: $DUP_PCT (threshold: 10%)"
  fi
else
  skip "jscpd not installed — run 'npm install -D jscpd' to enable"
fi
