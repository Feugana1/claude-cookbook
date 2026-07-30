#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 40. Presigned URL TTL ≤ 1h en affichage ─────────────────────────────────
# Pattern pentest (T15 Presigned URL lifecycle) : `getSignedUrl(key, '24h')`
# rend la révocation impossible pendant 24h en cas de fuite. TTL 1h par
# défaut sur endpoints d'affichage — les URLs sont régénérées à chaque
# chargement de page, impact fonctionnel nul.
#
# Whitelist par nom de fichier (grep -v) :
#   - *export*.ts : ZIP export envoyé par email (click différé, 24h OK)
#   - *multipart*.ts : session upload multipart (4h OK)
#   - storage_service.ts : abstraction elle-même (doc/comments)
#   - annotation `canonical-skip:presigned-ttl` pour cas exceptionnels
step 40 "Presigned URL expiresIn ≤ 1h en affichage" 3 "A05 Misconfig"

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

LONG_MATCHES=$({ grep -rnE "getSignedUrl|SIGN_TTL|expiresIn" $CONTROLLERS_DIR $SERVICES_DIR --include="*.ts" 2>/dev/null || true; } | \
  { grep -E "'(2h|3h|4h|6h|8h|10h|12h|24h)'|expiresIn:\s*[1-9][0-9]{4,}" || true; } | \
  { grep -v \
    -e "_export_service" \
    -e "_multipart_service" \
    -e "storage_service.ts" \
    -e "canonical-skip:presigned-ttl" || true; })
LONG_URLS=$(printf '%s' "$LONG_MATCHES" | { grep -c . || true; })
if [ "${LONG_URLS:-0}" -eq 0 ]; then
  pass "Toutes les presigned URL ≤ 1h (hors whitelist export ZIP + multipart upload)"
else
  fail "$LONG_URLS presigned URL > 1h détectée(s) — révocation lente en cas de fuite"
  printf '%s' "$LONG_MATCHES" | head -5 | while IFS= read -r line; do echo "    $line"; done
fi
