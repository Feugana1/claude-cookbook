#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 26. CORS — locked to own domains (not '*' in production) ───────────────
# Browser-side protection : la config CORS doit lister explicitement les origins
# autorisés. '*' en prod = malveillant site peut lire les responses depuis le
# browser de la victime (cf OWASP A05).
step 26 "CORS configuration (origin lock)" 2 "A05 Misconfig"
CORS_FILES=$(ls config/cors.ts start/cors.ts 2>/dev/null || true)
# Detect API cross-origin endpoints : si le projet n'a que des routes
# /api/* avec Bearer token auth ET pas de @adonisjs/cors → SPA same-domain,
# CORS pas requis. Si /api/* présent + pas de config CORS → vrai gap.
CROSS_ORIGIN_API=$(grep -rln "router\.group.*'/api'\|prefix:\s*['\"]\/api" start/routes.ts start/routes/ 2>/dev/null || true)
if [ -z "$CORS_FILES" ]; then
  if [ -z "$CROSS_ORIGIN_API" ]; then
    pass "No CORS config required — same-origin SPA (no /api cross-origin routes detected)"
  else
    warn "config/cors.ts missing but /api routes detected — verify @adonisjs/cors if external clients consume API"
  fi
else
  CORS_STAR=""
  for f in $CORS_FILES; do
    # Detect origin: '*' OU origin: true sans whitelist conditionnelle
    STAR_FOUND=$(grep -nE "origin:\s*['\"]\\*['\"]|origin:\s*true\s*[,}]" "$f" 2>/dev/null | grep -v "//.*canonical-skip:cors" || true)
    if [ -n "$STAR_FOUND" ]; then
      CORS_STAR="${CORS_STAR}${STAR_FOUND}"$'\n'
    fi
  done
  CORS_STAR=$(printf '%s' "$CORS_STAR" | grep -v '^$' || true)
  if [ -z "$CORS_STAR" ]; then
    pass "CORS origins locked (no wildcard '*' or unconditional true)"
  else
    fail "CORS wildcard detected — lock to APP_URL whitelist in production"
    echo "$CORS_STAR" | head -3 | while IFS= read -r line; do echo "    $line"; done
  fi
fi
