#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 58. Expo — sauvegarde Android des données de l'app (MASVS-STORAGE-2) ─────
# `android.allowBackup` vaut true par défaut (défaut Android) : les données de
# l'app (AsyncStorage, SQLite, fichiers) partent dans la sauvegarde Google et
# peuvent être restaurées ailleurs. À mettre à false dès que l'app stocke des
# données sensibles. WARN si absent ou true, PASS si false.
step 58 "Expo — Android allowBackup disabled" 2 "A05 Misconfig"
# shellcheck source=lib-expo.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib-expo.sh"

if ! expo_is_project; then
  skip "not an Expo project (no expo dependency in package.json)"
else
  EXPO_AB_FILES=$( { for f in app.json app.config.ts app.config.js app.config.mjs app.config.cjs android/app/src/main/AndroidManifest.xml; do [ ! -f "$f" ] || echo "$f"; done; } | expo_changed_filter)
  if [ -z "$EXPO_AB_FILES" ]; then
    if [ "${MODE:-full}" = "diff" ]; then
      skip "no app config / AndroidManifest touched — full check pre-push"
    else
      skip "no app.json / app.config / AndroidManifest.xml found"
    fi
  elif [ -f app.json ] && command -v jq >/dev/null 2>&1 \
    && [ "$(jq -r '((.expo // .).platforms // ["android"]) | index("android") | . != null' app.json 2>/dev/null)" = "false" ]; then
    skip "Android not in expo.platforms"
  else
    EXPO_AB=""
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      EXPO_AB="${EXPO_AB}$(grep -nHE "allowBackup[\"']?[[:space:]]*[:=][[:space:]]*[\"']?(true|false)" "$f" 2>/dev/null || true)"$'\n'
    done <<< "$EXPO_AB_FILES"
    EXPO_AB=$(printf '%s\n' "$EXPO_AB" | grep . || true)
    if [ -z "$EXPO_AB" ]; then
      warn "android.allowBackup not set — Android defaults to true; set false if the app stores sensitive data"
    elif printf '%s\n' "$EXPO_AB" | grep -qE "allowBackup[\"']?[[:space:]]*[:=][[:space:]]*[\"']?true"; then
      warn "android.allowBackup is true — app data is included in device backups"
      expo_show "$EXPO_AB" 3
    else
      pass "android.allowBackup disabled"
    fi
  fi
fi
