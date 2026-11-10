#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 55. Expo — dépendances alignées sur le SDK (npx expo install --check) ────
# Un module natif hors de la version attendue par le SDK compile parfois puis
# plante au runtime. Requiert node_modules et le réseau : SKIP hors-ligne
# (ou SECU_OFFLINE=1), en --diff, et au-delà de SECU_EXPO_TIMEOUT secondes (90).
step 55 "Expo — dependencies aligned with the SDK (expo install --check)" 3 "Supply chain"
# shellcheck source=lib-expo.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib-expo.sh"

if ! expo_is_project; then
  skip "not an Expo project (no expo dependency in package.json)"
elif skip_if_diff; then :
elif [ "${SECU_OFFLINE:-0}" = "1" ]; then
  skip "SECU_OFFLINE=1 — run 'npx expo install --check' when online"
elif [ ! -x node_modules/.bin/expo ]; then
  skip "node_modules/.bin/expo missing — run 'npm install' first"
else
  EXPO_RC=0
  EXPO_OUT=$(CI=1 EXPO_NO_TELEMETRY=1 expo_with_timeout "${SECU_EXPO_TIMEOUT:-90}" npx --no-install expo install --check 2>&1) || EXPO_RC=$?
  if [ "$EXPO_RC" -eq 0 ]; then
    pass "Dependencies match the installed Expo SDK"
  elif [ "$EXPO_RC" -eq 142 ]; then
    skip "expo install --check timed out (${SECU_EXPO_TIMEOUT:-90}s) — run it manually"
  elif expo_is_network_error "$EXPO_OUT"; then
    skip "offline — expo install --check needs the network"
  else
    warn "Dependencies out of line with the Expo SDK — run 'npx expo install --fix'"
    expo_show "$(printf '%s\n' "$EXPO_OUT" | grep -E 'expected|should be updated|-|@' || printf '%s' "$EXPO_OUT")" 6
  fi
fi
