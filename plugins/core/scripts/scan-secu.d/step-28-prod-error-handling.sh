#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 28. Production error handling (no stack trace leak) ────────────────────
# Default debug pages (stack trace, env, file paths) = info disclosure massive.
# Multi-stack support :
#   - Adonis  : app/exceptions/handler.ts (debug guard + custom pages)
#   - NestJS  : ExceptionFilter / HttpExceptionFilter par service
#   - Express : error handler middleware (4 args) avec NODE_ENV guard
step 28 "Production error handling (no stack trace leak)" 2 "A05 Misconfig"

ADONIS_HANDLER="app/exceptions/handler.ts"
NEST_FILTERS=$(grep -rln "ExceptionFilter\|@Catch\|HttpExceptionFilter" \
  services/*/src apps/*/src src 2>/dev/null || true)
# NestJS detected via @nestjs/core import (default exception filter sanitize prod)
NEST_APPS=$(grep -rln "@nestjs/core\|NestFactory\.create" \
  services/*/src/main.ts apps/*/src/main.ts src/main.ts 2>/dev/null || true)
EXPRESS_ERR_HANDLER=$(grep -rln "app\.use(\s*(\s*err\|app\.use(\s*function\s*(\s*err\|app\.use(\s*\(err," \
  services/*/src/main.ts apps/*/src/main.ts src/main.ts 2>/dev/null || true)

if [ -f "$ADONIS_HANDLER" ]; then
  # ── Adonis path
  DEBUG_GUARD=$(grep -n "debug.*inProduction\|debug.*=.*!.*production\|debug:.*!app\.inProduction" "$ADONIS_HANDLER" 2>/dev/null || true)
  RENDER_STATUS=$(grep -n "renderStatusPages.*inProduction\|renderStatusPages.*=.*app\.inProduction" "$ADONIS_HANDLER" 2>/dev/null || true)
  CUSTOM_500=$(ls resources/views/pages/errors/server_error.edge resources/views/errors/server_error.edge 2>/dev/null | head -1 || true)
  CUSTOM_404=$(ls resources/views/pages/errors/not_found.edge resources/views/errors/not_found.edge 2>/dev/null | head -1 || true)
  ISSUES=""
  [ -z "$DEBUG_GUARD" ] && ISSUES="${ISSUES}    - debug flag not tied to app.inProduction"$'\n'
  [ -z "$RENDER_STATUS" ] && ISSUES="${ISSUES}    - renderStatusPages not tied to app.inProduction"$'\n'
  [ -z "$CUSTOM_500" ] && ISSUES="${ISSUES}    - custom 500 page missing (pages/errors/server_error.edge)"$'\n'
  [ -z "$CUSTOM_404" ] && ISSUES="${ISSUES}    - custom 404 page missing (pages/errors/not_found.edge)"$'\n'
  if [ -z "$ISSUES" ]; then
    pass "Debug off in prod + custom error pages present (server_error + not_found)"
  else
    fail "Production error handling gaps:"
    printf '%s' "$ISSUES"
  fi
elif [ -n "$NEST_FILTERS" ]; then
  # ── NestJS path : ExceptionFilter custom détecté
  COUNT=$(echo "$NEST_FILTERS" | wc -l | tr -d ' ')
  PROD_GUARD=$(grep -rln "isProd\|NODE_ENV.*production\|process\.env\.NODE_ENV" $NEST_FILTERS 2>/dev/null || true)
  if [ -z "$PROD_GUARD" ]; then
    warn "$COUNT ExceptionFilter(s) trouvé(s) mais aucun guard NODE_ENV détecté — vérifier stack trace pas exposé en prod"
  else
    pass "$COUNT ExceptionFilter(s) avec guard prod (NODE_ENV/isProd)"
  fi
elif [ -n "$NEST_APPS" ]; then
  # ── NestJS app sans filter custom : default BaseExceptionFilter sanitize prod
  # (Stack trace pas exposé via HttpException.getResponse() en production)
  COUNT=$(echo "$NEST_APPS" | wc -l | tr -d ' ')
  pass "$COUNT NestJS app(s) — default BaseExceptionFilter sanitize stack en prod"
elif [ -n "$EXPRESS_ERR_HANDLER" ]; then
  # ── Express path : error handler middleware (4 args)
  PROD_GUARD=$(grep -rln "NODE_ENV.*production\|process\.env\.NODE_ENV" $EXPRESS_ERR_HANDLER 2>/dev/null || true)
  if [ -z "$PROD_GUARD" ]; then
    warn "Express error handler trouvé mais aucun guard NODE_ENV — vérifier stack trace pas exposé"
  else
    pass "Express error handler avec guard prod"
  fi
elif [ -f package.json ] && grep -qE '"(expo|react-native)"[[:space:]]*:' package.json; then
  # Mobile client (Expo / React Native) : no HTTP server, the check belongs to the backend repo.
  skip "Mobile client app — no HTTP server here; run this step in the backend repo"
else
  fail "No exception handler found — expected app/exceptions/handler.ts (Adonis), @Catch ExceptionFilter (NestJS), or app.use((err,req,res,next)) (Express)"
fi
