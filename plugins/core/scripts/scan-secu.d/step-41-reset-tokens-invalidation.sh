#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 41. Reset tokens antérieurs invalidés avant émission ────────────────────
# Pattern pentest (T11 Auth lifecycle) : l'endpoint `forgot-password` DOIT
# invalider les tokens PASSWORD_RESET actifs du user AVANT d'en créer un
# nouveau. Sinon 2+ tokens simultanés valides 1h → fenêtre d'exposition
# élargie (lien retrouvé dans boîte transférée / compromise partielle).
step 41 "Reset tokens antérieurs invalidés avant émission" 2 "A07 Auth"

# Détecte le fichier ForgotPassword controller
RESET_FILE=""
for candidate in \
  "app/controllers/auth/forgot_password_controller.ts" \
  "src/controllers/auth/forgot_password.controller.ts" \
  "src/auth/forgot-password.controller.ts"; do
  [ -f "$candidate" ] && RESET_FILE="$candidate" && break
done

if [ -z "$RESET_FILE" ]; then
  skip "No forgot password controller found (checked common paths)"
  return 0 2>/dev/null || true
fi

# Heuristique multi-ligne : chercher un update({isRevoked: true}) sur Token.query
# qui apparaît AVANT le Token.create dans le fichier (awk scanne linéairement).
DETECT=$(awk '
  /Token\.query\(\)|passwordResetToken.query\(\)/ { in_query=1 }
  in_query && /update\(\{[^}]*isRevoked:[[:space:]]*true|update\(\{[^}]*revokedAt/ { invalidated=1; in_query=0 }
  /await Token\.create|await this\.tokenRepository\.save|await prisma\.token\.create/ && !invalidated { print "MISSING"; exit }
  /await Token\.create|await this\.tokenRepository\.save|await prisma\.token\.create/ && invalidated { print "OK"; exit }
' "$RESET_FILE")

if [ "$DETECT" = "OK" ]; then
  pass "forgot_password_controller invalide les tokens antérieurs avant émission"
elif [ "$DETECT" = "MISSING" ]; then
  fail "forgot_password_controller n'invalide PAS les tokens antérieurs avant émission"
else
  warn "Pattern reset tokens non détecté — vérifier manuellement $RESET_FILE"
fi
