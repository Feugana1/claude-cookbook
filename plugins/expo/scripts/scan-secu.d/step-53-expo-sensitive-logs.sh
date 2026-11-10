#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 53. Expo — secrets et session dans les journaux ─────────────────────────
# MASVS-CODE / OWASP A09 : console.* finit dans logcat / Console.app et dans les
# breadcrumbs Sentry. Détecte un identifiant sensible (token, password, secret,
# authorization) passé en argument ou interpolé (pas une simple mention textuelle).
step 53 "Expo — tokens / passwords passed to console.*" 2 "A09 Logging"
# shellcheck source=lib-expo.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib-expo.sh"

if ! expo_is_project; then
  skip "not an Expo project (no expo dependency in package.json)"
else
  EXPO_LOGS=$(expo_grep -i "console\.(log|info|debug|warn|error|trace)\(.*([,(][[:space:]]*|\\\$\{)[A-Za-z0-9_\$.?]*(token|jwt|password|passwd|secret|authorization|credential)")
  if [ -n "$EXPO_LOGS" ]; then
    fail "$(expo_count "$EXPO_LOGS") console.* call(s) logging a token / password / Authorization value"
    expo_show "$EXPO_LOGS"
  else
    pass "No sensitive value passed to console.*"
  fi
  # Sentry : scrubber recommandé dès que le SDK est présent.
  if grep -q '"@sentry/react-native"' package.json 2>/dev/null && [ "${MODE:-full}" = "full" ]; then
    if [ -z "$(expo_files_matching 'beforeSend|beforeBreadcrumb')" ]; then
      warn "@sentry/react-native without beforeSend / beforeBreadcrumb — scrub Authorization headers and request bodies"
    fi
  fi
fi
