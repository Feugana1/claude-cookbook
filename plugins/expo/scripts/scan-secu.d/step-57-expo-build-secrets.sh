#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 57. Expo — secrets de build (eas.json, app.config) et sourcemaps versionnées ─
# - eas.json `build.<profil>.env` est versionné : un secret (TOKEN, SECRET, PASSWORD,
#   PRIVATE, *_KEY) y est en clair. Le déclarer en variable d'environnement EAS
#   (`eas env:create --visibility secret|sensitive`).
# - `authToken` littéral dans la config d'un plugin (ex. Sentry) : même fuite.
# - Sourcemaps / exports (`dist/`, `web-build/`, `*.map`) commités : code source et
#   endpoints internes reconstructibles.
step 57 "Expo — build secrets in eas.json / app config, committed sourcemaps" 2 "A05 Misconfig"
# shellcheck source=lib-expo.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib-expo.sh"

if ! expo_is_project; then
  skip "not an Expo project (no expo dependency in package.json)"
else
  EXPO_BUILD_ISSUES=""
  EXPO_SECRET_NAME='SECRET|TOKEN|PASSWORD|PASSWD|PRIVATE|CREDENTIAL|_KEY$'
  EXPO_CFG=$(expo_config_files)
  if printf '%s\n' "$EXPO_CFG" | grep -qx 'eas.json'; then
    if command -v jq >/dev/null 2>&1; then
      EXPO_EAS_SECRETS=$(jq -r '(.build // {}) | to_entries[] | .key as $p | (.value.env // {}) | to_entries[] | select(.value | type == "string" and (startswith("$") | not)) | "eas.json: build.\($p).env.\(.key)"' eas.json 2>/dev/null \
        | grep -E "env\.[A-Z0-9_]*($EXPO_SECRET_NAME)" | grep -v 'env\.EXPO_PUBLIC_' || true)
    else
      EXPO_EAS_SECRETS=$(grep -nHE "\"[A-Z0-9_]*(SECRET|TOKEN|PASSWORD|PRIVATE|CREDENTIAL)[A-Z0-9_]*\"[[:space:]]*:[[:space:]]*\"[^\"$]" eas.json | grep -v 'EXPO_PUBLIC_' || true)
    fi
    [ -z "$EXPO_EAS_SECRETS" ] || EXPO_BUILD_ISSUES="${EXPO_BUILD_ISSUES}${EXPO_EAS_SECRETS}"$'\n'
  fi
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    EXPO_TOK=$(grep -nHE "authToken[\"']?[[:space:]]*:[[:space:]]*[\"'][^\"'\$]{8,}" "$f" 2>/dev/null | grep -v 'canonical-skip:' || true)
    [ -z "$EXPO_TOK" ] || EXPO_BUILD_ISSUES="${EXPO_BUILD_ISSUES}${EXPO_TOK}"$'\n'
  done <<< "$EXPO_CFG"
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    EXPO_MAPS=$(git ls-files -- '*.map' 'dist/*' 'web-build/*' 2>/dev/null | grep -v 'node_modules/' | expo_changed_filter | head -20 || true)
    [ -z "$EXPO_MAPS" ] || EXPO_BUILD_ISSUES="${EXPO_BUILD_ISSUES}$(printf '%s\n' "$EXPO_MAPS" | sed 's/$/: committed build output \/ sourcemap/')"$'\n'
  fi
  EXPO_BUILD_ISSUES=$(printf '%s\n' "$EXPO_BUILD_ISSUES" | grep . || true)
  if [ -n "$EXPO_BUILD_ISSUES" ]; then
    fail "$(expo_count "$EXPO_BUILD_ISSUES") build secret(s) in versioned config or committed sourcemap(s)"
    expo_show "$EXPO_BUILD_ISSUES"
    echo "    Fix : 'eas env:create --visibility secret', process.env in app.config, untrack dist/ and *.map"
  elif [ "${MODE:-full}" = "diff" ] && [ -z "$EXPO_CFG" ]; then
    skip "no eas.json / app config touched — full check pre-push"
  else
    pass "No build secret in eas.json / app config, no committed sourcemap"
  fi
fi
