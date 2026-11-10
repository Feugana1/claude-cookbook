#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 52. Expo — trafic en clair : cleartext Android, ATS iOS, URL http:// ────
# MASVS-NETWORK-1 : HTTPS partout en release. `usesCleartextTraffic: true`
# (app.json, expo-build-properties ou AndroidManifest) et `NSAllowsArbitraryLoads`
# désactivent la protection de la plateforme. Une base URL d'API en http://
# (hors localhost / 10.0.2.2 de dev) envoie tokens et données en clair.
step 52 "Expo — cleartext traffic (Android cleartext, iOS ATS, http:// API URLs)" 2 "A05 Misconfig"
# shellcheck source=lib-expo.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib-expo.sh"

if ! expo_is_project; then
  skip "not an Expo project (no expo dependency in package.json)"
else
  EXPO_NATIVE_FILES=$( { expo_config_files; ls -1 android/app/src/main/AndroidManifest.xml ios/*/Info.plist 2>/dev/null || true; } | expo_changed_filter | sort -u)
  EXPO_CLEAR=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    EXPO_CLEAR="${EXPO_CLEAR}$(grep -nHE "usesCleartextTraffic[\"']?[[:space:]]*[:=][[:space:]]*[\"']?true|NSAllowsArbitraryLoads[\"']?[[:space:]]*[:=][[:space:]]*true" "$f" 2>/dev/null | grep -v 'canonical-skip:' || true)"$'\n'
    if grep -q '<key>NSAllowsArbitraryLoads</key>' "$f" 2>/dev/null; then
      EXPO_CLEAR="${EXPO_CLEAR}$(grep -nH -A1 '<key>NSAllowsArbitraryLoads</key>' "$f" | grep '<true/>' || true)"$'\n'
    fi
  done <<< "$EXPO_NATIVE_FILES"
  EXPO_CLEAR=$(printf '%s\n' "$EXPO_CLEAR" | grep . || true)

  EXPO_HTTP=$(expo_grep "[\"'\`]http://" \
    | grep -vE 'http://(localhost|127\.0\.0\.1|0\.0\.0\.0|10\.0\.2\.2|10\.0\.3\.2|192\.168\.|\[::1\])' \
    | grep -viE 'w3\.org|xmlns|schemas\.|purl\.org|ns\.adobe\.com' || true)
  EXPO_HTTP_API=$(printf '%s\n' "$EXPO_HTTP" | grep -iE 'api|base|url|endpoint|host|server|origin|fetch|axios|ws' || true)

  if [ -n "$EXPO_CLEAR$EXPO_HTTP_API" ]; then
    fail "$(expo_count "$EXPO_CLEAR$EXPO_HTTP_API") cleartext setting(s) or http:// API URL(s) — HTTPS only in release"
    expo_show "$EXPO_CLEAR"$'\n'"$EXPO_HTTP_API"
  else
    pass "No cleartext / ATS bypass in Expo config, no http:// API URL in sources"
  fi
  EXPO_HTTP_OTHER=$(printf '%s\n' "$EXPO_HTTP" | grep -viE 'api|base|url|endpoint|host|server|origin|fetch|axios|ws' | grep . || true)
  if [ -n "$EXPO_HTTP_OTHER" ]; then
    warn "$(expo_count "$EXPO_HTTP_OTHER") other http:// literal(s) — switch to https:// where possible"
    expo_show "$EXPO_HTTP_OTHER" 3
  fi
fi
