#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 54. Expo — paramètres de deep link utilisés sans validation (heuristique) ─
# N'importe quelle app peut ouvrir le scheme de l'app avec des paramètres choisis.
# Un paramètre de route (`redirect`, `returnTo`, `next`, `url`…) passé tel quel à
# router.push/replace, <Redirect href>, Linking.openURL ou une WebView = open
# redirect / navigation forcée (MASVS-PLATFORM-1). Heuristique : le fichier lit des
# paramètres, les passe à une navigation, et ne montre aucune validation
# (schéma zod/valibot/yup, safeParse, allowlist, startsWith('/')). WARN, à confirmer.
step 54 "Expo — deep link / route params reused without validation (heuristic)" 2 "A01 Access Control"
# shellcheck source=lib-expo.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib-expo.sh"

if ! expo_is_project; then
  skip "not an Expo project (no expo dependency in package.json)"
else
  EXPO_PARAM_FILES=$(expo_files_matching 'useLocalSearchParams|useGlobalSearchParams|Linking\.(parse|getInitialURL)|useURL\(|redirectSystemPath')
  if [ -z "$EXPO_PARAM_FILES" ]; then
    pass "No route / deep link parameter reader in scope"
  else
    EXPO_NAV_SINK="(router\.(push|replace|navigate)|Linking\.openURL|openBrowserAsync|<Redirect[^>]*href=)[[:space:]]*\(?[[:space:]]*\{?[[:space:]]*(params\.|searchParams\.)?(redirect|returnTo|return_to|next|callback|url|link|target|href|to)([^A-Za-z0-9_]|$)"
    EXPO_VALIDATION='safeParse|\.parse\(|z\.object|v\.object|yup\.|allowlist|allowList|ALLOWED|isSafe|isInternal|startsWith\(['"'"'"]/'
    EXPO_UNSAFE=""
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      EXPO_SINK=$(grep -nHE "$EXPO_NAV_SINK" "$f" 2>/dev/null | grep -v 'canonical-skip:' || true)
      if [ -n "$EXPO_SINK" ] && ! grep -qE "$EXPO_VALIDATION" "$f"; then
        EXPO_UNSAFE="${EXPO_UNSAFE}${EXPO_SINK}"$'\n'
      fi
    done <<< "$EXPO_PARAM_FILES"
    EXPO_UNSAFE=$(printf '%s\n' "$EXPO_UNSAFE" | grep . || true)
    if [ -n "$EXPO_UNSAFE" ]; then
      warn "$(expo_count "$EXPO_UNSAFE") navigation(s) driven by a route param without visible validation — check open redirect"
      expo_show "$EXPO_UNSAFE"
      echo "    Fix : validate params with a schema and restrict redirects to an allowlist of internal paths"
    else
      pass "$(expo_count "$EXPO_PARAM_FILES") param-reading file(s), no unvalidated param-driven navigation detected"
    fi
  fi
fi
