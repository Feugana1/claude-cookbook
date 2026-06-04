#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 28. Production error handling (debug off + custom error pages) ─────────
# Default debug pages (stack trace, env, file paths) = info disclosure massive.
# handler.ts doit avoir `debug = !inProduction` ET pages d'erreur custom.
step 28 "Production error handling (no stack trace leak)" 2 "A05 Misconfig"
HANDLER_FILE="app/exceptions/handler.ts"
if [ ! -f "$HANDLER_FILE" ]; then
  fail "$HANDLER_FILE not found — Adonis exception handler missing"
else
  DEBUG_GUARD=$(grep -n "debug.*inProduction\|debug.*=.*!.*production\|debug:.*!app\.inProduction" "$HANDLER_FILE" 2>/dev/null || true)
  RENDER_STATUS=$(grep -n "renderStatusPages.*inProduction\|renderStatusPages.*=.*app\.inProduction" "$HANDLER_FILE" 2>/dev/null || true)
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
fi
