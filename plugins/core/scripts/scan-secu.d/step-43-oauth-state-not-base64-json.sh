#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 43. OAuth state pas base64(JSON({userId})) prévisible ───────────────────
# Pattern pentest (T12 OAuth flow integrity) : le paramètre `state` OAuth
# DOIT être aléatoire fort (CSPRNG ≥ 128 bits), stocké côté session avec
# TTL court, comparé strictement au retour. `Buffer.from(JSON.stringify(
# {userId})).toString('base64')` est forgeable trivialement — protection
# CSRF absente.
#
# Fix : `randomBytes(32).toString('hex')` + session.put + expiration ≤ 10min.
# Whitelist `canonical-skip:oauth-state` pour documentation de l'anti-pattern.
step 43 "OAuth state pas base64(JSON) prévisible" 1 "A04 Insecure Design"

CONTROLLERS_DIR=""
SERVICES_DIR=""
[ -d app/controllers ] && CONTROLLERS_DIR="app/controllers"
[ -d src/controllers ] && CONTROLLERS_DIR="src/controllers"
[ -d app/services ] && SERVICES_DIR="app/services"
[ -d src/services ] && SERVICES_DIR="src/services"

if [ -z "$CONTROLLERS_DIR" ] && [ -z "$SERVICES_DIR" ]; then
  skip "no controllers/ services/ dirs — check manually"
  return 0 2>/dev/null || true
fi

BASE64_STATES=$({ grep -rnE "Buffer\.from\(JSON\.stringify\([^)]*userId" $CONTROLLERS_DIR $SERVICES_DIR --include="*.ts" 2>/dev/null || true; } | \
  { grep -v "canonical-skip:oauth-state" || true; })
BASE64_COUNT=$(printf '%s' "$BASE64_STATES" | { grep -c . || true; })

if [ "${BASE64_COUNT:-0}" -eq 0 ]; then
  pass "Aucun OAuth state en base64(JSON({userId})) prévisible"
else
  fail "$BASE64_COUNT état(s) OAuth encodé(s) base64(JSON({userId})) — forgeable"
  printf '%s' "$BASE64_STATES" | head -3 | while IFS= read -r line; do echo "    $line"; done
fi
