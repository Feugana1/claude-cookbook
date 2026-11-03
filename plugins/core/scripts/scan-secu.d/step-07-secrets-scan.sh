#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 7. Secrets scan ────────────────────────────────────────────────────────
step 7 "Secrets scan (hardcoded credentials)" 1 "A02 Crypto"
SECRETS=$(grep -rn 'password\s*=\s*["\x27][^"\x27]*["\x27]' app/ config/ start/ --include="*.ts" 2>/dev/null \
  | grep -vi 'eslint\|placeholder\|validator\|env\.\|hash\.\|schema\|type.*password\|name.*password\|autocomplete\|payload\|test\|spec\|factory\|seed\|let password\|const password' \
  || true)
if [ -z "$SECRETS" ]; then
  pass "No hardcoded credentials detected"
else
  COUNT=$(echo "$SECRETS" | wc -l | tr -d ' \r')
  warn "$COUNT potential hardcoded secrets — review manually"
  echo "$SECRETS" | head -5 | while IFS= read -r line; do echo "    $line"; done
fi
