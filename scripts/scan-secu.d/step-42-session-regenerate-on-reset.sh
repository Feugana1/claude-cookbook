#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 42. Session.regenerate() sur password reset ─────────────────────────────
# Pattern pentest (T11 Auth lifecycle) : le controller reset-password DOIT
# invalider la session courante après changement de mot de passe — sinon
# cookie volé AVANT reset reste utilisable indéfiniment.
#
# Multi-stack :
#   - Adonis : `session.regenerate()` du service session
#   - NestJS : `req.session.regenerate()` ou destroy + login again
#   - Express + express-session : `req.session.regenerate()`
step 42 "session.regenerate() sur password reset" 2 "A07 Auth"

RESET_FILE=""
for candidate in \
  "app/controllers/auth/reset_password_controller.ts" \
  "src/controllers/auth/reset_password.controller.ts" \
  "src/auth/reset-password.controller.ts"; do
  [ -f "$candidate" ] && RESET_FILE="$candidate" && break
done

if [ -z "$RESET_FILE" ]; then
  skip "No reset password controller found (checked common paths)"
  return 0 2>/dev/null || true
fi

if grep -qE "session\.regenerate|session\.destroy|regenerateSession|sessionVersion" "$RESET_FILE" 2>/dev/null; then
  pass "reset_password_controller invalide la session courante"
else
  fail "reset_password_controller manque session.regenerate() / destroy après password change"
fi
