#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 50. Expo — secrets de session en stockage non chiffré (MASVS-STORAGE-1) ──
# Tokens, refresh tokens et mots de passe : uniquement expo-secure-store (Keychain /
# Keystore). AsyncStorage, MMKV non chiffré, SQLite et localStorage sont lisibles
# via sauvegarde ou appareil rooté. Complément : SecureStore sans keychainAccessible
# explicite, cache TanStack persisté sans filtre de déshydratation.
# Exception justifiée : `// canonical-skip:storage-P0:<raison>` sur la ligne.
step 50 "Expo — session secrets in unencrypted storage" 1 "A02 Crypto"
# shellcheck source=lib-expo.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib-expo.sh"

if ! expo_is_project; then
  skip "not an Expo project (no expo dependency in package.json)"
else
  EXPO_SENS='token|jwt|passw|secret|credential|refresh|session|auth[^o]'
  EXPO_INSECURE=$(expo_grep -i "(AsyncStorage\.(setItem|multiSet|mergeItem)|[a-z_]*(storage|mmkv|kv)\.(set|setString|setItem))\([[:space:]]*[^,)]*($EXPO_SENS)" | grep -vi 'secure' || true)
  EXPO_SQL=$(expo_grep -i "(insert into|update)[^;]*(access_?token|refresh_?token|password)" || true)
  if [ -n "$EXPO_INSECURE$EXPO_SQL" ]; then
    fail "$(expo_count "$EXPO_INSECURE$EXPO_SQL") session secret write(s) to unencrypted storage — use expo-secure-store"
    expo_show "$EXPO_INSECURE"$'\n'"$EXPO_SQL"
  else
    pass "No session secret written to AsyncStorage / MMKV / SQLite"
  fi

  # SecureStore : préciser keychainAccessible (sinon défaut WHEN_UNLOCKED, sauvegardé et migrable).
  EXPO_SS_FILES=$(expo_files_matching 'SecureStore\.setItem(Async)?\(')
  EXPO_SS_NO_ACL=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -q 'keychainAccessible' "$f" || EXPO_SS_NO_ACL="${EXPO_SS_NO_ACL}${f}"$'\n'
  done <<< "$EXPO_SS_FILES"
  if [ -n "$EXPO_SS_NO_ACL" ]; then
    warn "SecureStore writes without explicit keychainAccessible — prefer WHEN_UNLOCKED_THIS_DEVICE_ONLY"
    expo_show "$EXPO_SS_NO_ACL" 3
  fi

  # Cache TanStack persisté : exclure tokens et PII de la déshydratation.
  EXPO_PERSIST=$(expo_files_matching 'createAsyncStoragePersister|createSyncStoragePersister|PersistQueryClientProvider|persistQueryClient')
  EXPO_PERSIST_NOFILTER=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -q 'shouldDehydrateQuery' "$f" || EXPO_PERSIST_NOFILTER="${EXPO_PERSIST_NOFILTER}${f}"$'\n'
  done <<< "$EXPO_PERSIST"
  if [ -n "$EXPO_PERSIST_NOFILTER" ]; then
    warn "Persisted query cache without dehydrateOptions.shouldDehydrateQuery — make sure no token / PII query is persisted"
    expo_show "$EXPO_PERSIST_NOFILTER" 3
  fi
fi
