#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 51. Expo — secrets exposés via EXPO_PUBLIC_* ────────────────────────────
# Toute variable EXPO_PUBLIC_* est inlinée en clair dans le bundle JS livré.
# Un nom de secret (SECRET, PASSWORD, PRIVATE, SERVICE_ROLE, *_TOKEN serveur) y est
# donc une fuite. Les clés publiques par conception (publishable, anon, restreintes
# au bundle id) passent en WARN à vérifier.
step 51 "Expo — secrets exposed through EXPO_PUBLIC_*" 1 "A02 Crypto"
# shellcheck source=lib-expo.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib-expo.sh"

if ! expo_is_project; then
  skip "not an Expo project (no expo dependency in package.json)"
else
  EXPO_ENV_FILES=$( { ls -1 .env .env.* 2>/dev/null || true; expo_config_files; } | expo_changed_filter | sort -u)
  EXPO_PUB_RE='EXPO_PUBLIC_[A-Z0-9_]*(SECRET|PASSWORD|PASSWD|PRIVATE|SERVICE_ROLE|ACCESS_TOKEN|AUTH_TOKEN|REFRESH_TOKEN)'
  EXPO_PUB_HITS=$(expo_grep "$EXPO_PUB_RE")
  EXPO_PUB_WEAK=$(expo_grep 'EXPO_PUBLIC_[A-Z0-9_]*(_KEY|TOKEN)' | grep -vE 'PUBLISHABLE|PUBLIC_KEY|ANON_KEY' || true)
  if [ -n "$EXPO_ENV_FILES" ]; then
    EXPO_ENV_ARR=()
    while IFS= read -r f; do [ -n "$f" ] && EXPO_ENV_ARR+=("$f"); done <<< "$EXPO_ENV_FILES"
    EXPO_PUB_HITS="${EXPO_PUB_HITS}"$'\n'"$(grep -nHE "$EXPO_PUB_RE" "${EXPO_ENV_ARR[@]}" 2>/dev/null | grep -v 'canonical-skip:' || true)"
    EXPO_PUB_WEAK="${EXPO_PUB_WEAK}"$'\n'"$(grep -nHE 'EXPO_PUBLIC_[A-Z0-9_]*(_KEY|TOKEN)' "${EXPO_ENV_ARR[@]}" 2>/dev/null | grep -vE "PUBLISHABLE|PUBLIC_KEY|ANON_KEY|canonical-skip:" || true)"
  fi
  EXPO_PUB_HITS=$(printf '%s\n' "$EXPO_PUB_HITS" | grep . || true)
  EXPO_PUB_WEAK=$(printf '%s\n' "$EXPO_PUB_WEAK" | grep . | grep -vE "$EXPO_PUB_RE" || true)
  if [ -n "$EXPO_PUB_HITS" ]; then
    fail "$(expo_count "$EXPO_PUB_HITS") EXPO_PUBLIC_* variable(s) named like a secret — inlined in clear in the JS bundle"
    expo_show "$EXPO_PUB_HITS"
    echo "    Fix : keep the secret server-side, or in an EAS 'secret' variable without the EXPO_PUBLIC_ prefix"
  else
    pass "No secret-named EXPO_PUBLIC_* variable"
  fi
  if [ -n "$EXPO_PUB_WEAK" ]; then
    warn "$(expo_count "$EXPO_PUB_WEAK") EXPO_PUBLIC_*_KEY / *TOKEN reference(s) — confirm each value is public by design (restricted key)"
    expo_show "$EXPO_PUB_WEAK" 3
  fi
fi
