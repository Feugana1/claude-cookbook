#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 31. Webhook signature verification (Stripe + NotchPay) ─────────────────
# Webhooks money endpoints = vecteur replay attack. Stripe.webhooks.constructEvent
# OU verification HMAC NotchPay obligatoire AVANT business logic. Anti-pattern :
# controller webhook accepte payload sans verifier header signature.
step 31 "Webhook signature verification (money endpoints)" 1 "A04 Insecure Design"
WEBHOOK_FILES=$(grep -rln "stripe-signature\|notch-signature\|x-notchpay-signature\|webhook" app/controllers/ --include="*.ts" 2>/dev/null \
  | grep -iE "webhook|hook" | head -10 || true)
if [ -z "$WEBHOOK_FILES" ]; then
  skip "No webhook controllers detected"
else
  WEBHOOK_GAPS=""
  for f in $WEBHOOK_FILES; do
    # Détecte fichiers webhook qui font des INSERT/UPDATE/SAVE/PAYMENT sans
    # vérification signature préalable (constructEvent / verifyWebhook / HMAC verify)
    HAS_BUSINESS_LOGIC=$(grep -cE "\.save\(\)|\.create\(|\.update\(|PaymentService|InvoiceService|markAsPaid|fulfillOrder" "$f" 2>/dev/null || echo "0")
    HAS_SIG_CHECK=$(grep -cE "constructEvent|verifyWebhook|verifyHmac|crypto\.timingSafeEqual|signature\s*===|webhookSecret" "$f" 2>/dev/null || echo "0")
    if [ "$HAS_BUSINESS_LOGIC" -gt 0 ] && [ "$HAS_SIG_CHECK" -eq 0 ]; then
      WEBHOOK_GAPS="${WEBHOOK_GAPS}    - $f : business logic without signature check"$'\n'
    fi
  done
  WEBHOOK_GAPS=$(printf '%s' "$WEBHOOK_GAPS" | grep -v '^$' || true)
  if [ -z "$WEBHOOK_GAPS" ]; then
    NB=$(echo "$WEBHOOK_FILES" | wc -l | tr -d ' \r')
    pass "$NB webhook controller(s) verify signature before business logic"
  else
    fail "Webhook signature verification missing:"
    printf '%s' "$WEBHOOK_GAPS"
  fi
fi
