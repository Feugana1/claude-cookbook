#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 4. Crypto scan ─────────────────────────────────────────────────────────
step 4 "Crypto scan (weak randomness)" 1 "A02 Crypto"
CRYPTO_ISSUES=$(grep -rn "Math\.random" app/services/ app/controllers/ --include="*.ts" 2>/dev/null || true)
if [ -z "$CRYPTO_ISSUES" ]; then
  pass "No Math.random() in services/controllers"
else
  COUNT=$(echo "$CRYPTO_ISSUES" | wc -l | tr -d ' \r')
  fail "$COUNT uses of Math.random() — replace with crypto.randomInt()"
  echo "$CRYPTO_ISSUES" | head -5 | while IFS= read -r line; do echo "    $line"; done
fi
