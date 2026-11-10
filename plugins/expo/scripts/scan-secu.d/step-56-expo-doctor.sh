#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 56. Expo — expo-doctor (optionnel) ──────────────────────────────────────
# Contrôles officiels de santé du projet (config, dépendances dupliquées, versions
# natives, schéma app.json). Lancé si expo-doctor est installé localement, ou si
# SECU_EXPO_DOCTOR=1 (téléchargé via npx). SKIP hors-ligne et en --diff.
step 56 "Expo — expo-doctor (optional)" 3 "Supply chain"
# shellcheck source=lib-expo.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib-expo.sh"

if ! expo_is_project; then
  skip "not an Expo project (no expo dependency in package.json)"
elif skip_if_diff; then :
elif [ "${SECU_OFFLINE:-0}" = "1" ]; then
  skip "SECU_OFFLINE=1 — run 'npx expo-doctor' when online"
elif [ ! -x node_modules/.bin/expo-doctor ] && [ "${SECU_EXPO_DOCTOR:-0}" != "1" ]; then
  skip "optional — set SECU_EXPO_DOCTOR=1 to run 'npx expo-doctor' (downloads it)"
else
  EXPO_DOC_CMD=(npx --yes expo-doctor)
  [ ! -x node_modules/.bin/expo-doctor ] || EXPO_DOC_CMD=(node_modules/.bin/expo-doctor)
  EXPO_RC=0
  EXPO_OUT=$(CI=1 EXPO_NO_TELEMETRY=1 expo_with_timeout "${SECU_EXPO_TIMEOUT:-180}" "${EXPO_DOC_CMD[@]}" 2>&1) || EXPO_RC=$?
  if [ "$EXPO_RC" -eq 0 ]; then
    pass "expo-doctor: no issue"
  elif [ "$EXPO_RC" -eq 142 ]; then
    skip "expo-doctor timed out — run it manually"
  elif expo_is_network_error "$EXPO_OUT" && ! printf '%s' "$EXPO_OUT" | grep -q 'checks failed'; then
    skip "offline — expo-doctor needs the network"
  else
    warn "expo-doctor reported issue(s)"
    expo_show "$(printf '%s\n' "$EXPO_OUT" | grep -E '✖|failed|Advice|issue' || printf '%s' "$EXPO_OUT")" 6
  fi
fi
