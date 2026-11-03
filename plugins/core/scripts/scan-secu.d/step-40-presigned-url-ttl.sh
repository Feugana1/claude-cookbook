#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 40. Presigned URL TTL ≤ 1h en affichage (généraliste sémantique) ────────
# Pattern pentest T15 Presigned URL lifecycle : `getSignedUrl(key, '24h')`
# rend la révocation impossible en cas de fuite. TTL 1h par défaut en
# affichage — URLs régénérées à chaque page load, impact nul.
#
# Signal sémantique généraliste (v0.3+ cookbook) : détecte LA CLASSE
# (TTL long en affichage sans justification), pas les instances connues.
# Whitelist par filename SUPPRIMÉE (fragile face nouveaux sites legit :
# ZIP export, RGPD 7d, OG scraper 7d, PWA manifest, print-ready email).
#
# Justification obligatoire par commentaire `canonical-skip:presigned-ttl
# <raison>` dans les 5 lignes AVANT le match (contexte lu via sed).
#
# Regex étendu :
#   - 'Nh' avec N≥2 : '2h'..'99h'
#   - 'Nd' any days : '1d', '7d', '30d'
#   - expiresIn numeric ≥ 10000s (~3h+)
#   - expiresIn: N*3600 avec N≥2
step 40 "Presigned URL expiresIn ≤ 1h en affichage (canonical-skip justif)" 3 "A05 Misconfig"

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

LONG_URLS=0
LONG_SAMPLES=""
while IFS= read -r match; do
  [ -z "$match" ] && continue
  file="${match%%:*}"
  line_num="${match#*:}"
  line_num="${line_num%%:*}"
  ctx_start=$((line_num - 5))
  [ "$ctx_start" -lt 1 ] && ctx_start=1
  ctx=$(sed -n "${ctx_start},${line_num}p" "$file")
  if echo "$ctx" | grep -q "canonical-skip:presigned-ttl"; then
    continue
  fi
  LONG_URLS=$((LONG_URLS + 1))
  LONG_SAMPLES="${LONG_SAMPLES}$file:$line_num"$'\n'
done < <(grep -rnE "'([2-9]|[1-9][0-9])h'|'[1-9][0-9]*d'|expiresIn:[[:space:]]*[1-9][0-9]{4,}|expiresIn:[[:space:]]*[2-9][[:space:]]*\*[[:space:]]*3600" $CONTROLLERS_DIR $SERVICES_DIR --include="*.ts" 2>/dev/null || true)

if [ "${LONG_URLS:-0}" -eq 0 ]; then
  pass "Toutes presigned URL > 1h justifiées par commentaire canonical-skip:presigned-ttl"
else
  fail "$LONG_URLS presigned URL > 1h sans commentaire canonical-skip:presigned-ttl — révocation lente si fuite"
  printf '%s' "$LONG_SAMPLES" | head -5 | while IFS= read -r sample; do echo "    $sample"; done
fi
