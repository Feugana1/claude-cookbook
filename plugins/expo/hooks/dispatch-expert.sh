#!/usr/bin/env bash
# Claude Code hook — PostToolUse Edit|Write|MultiEdit (pack expo)
#
# Lit le JSON de l'événement sur stdin, grep les anti-patterns P0 grepables du
# fichier modifié, puis :
#   - exit 2 + stderr : un P0 est détecté. Claude reçoit le message et doit
#     corriger (l'édition est déjà faite : le hook ne l'annule pas).
#   - exit 0 + JSON `additionalContext` : conseils d'experts à invoquer.
#   - exit 0 silencieux sinon.
#
# Le hook ne lance JAMAIS de subagent : il bloque les P0 et suggère les experts.
#
# Exception ponctuelle et justifiée : une ligne contenant
# `canonical-skip:<règle>:<raison>` (en commentaire) est ignorée par les règles P0.
#
# Extension projet : si `.claude/hooks/dispatch-expert.local.sh` existe, il est
# sourcé après les règles et peut appeler `hint "texte"` pour ajouter ses
# propres conseils (experts domain du projet).
#
# Source de vérité des règles : docs/anti-patterns-expo.md.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "[hook:dispatch] jq introuvable : les contrôles P0 sont désactivés. Installer jq (brew install jq)." >&2
  exit 0
fi

input=$(cat 2>/dev/null || echo '{}')
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')
case "$tool" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
[ -n "$file" ] && [ -f "$file" ] || exit 0

project="${CLAUDE_PROJECT_DIR:-$(printf '%s' "$input" | jq -r '.cwd // empty')}"
project="${project:-$(pwd)}"
rel="${file#"$project"/}"

# Code généré ou tiers : jamais contrôlé.
case "$rel" in
  node_modules/*|*/node_modules/*|ios/Pods/*|android/build/*|android/app/build/*|.expo/*|dist/*|web-build/*) exit 0 ;;
esac

HINTS=()
hint() { HINTS+=("$1"); }
block() {
  echo "[hook:$1] BLOCKED — $2 Corriger avant de continuer (exception justifiée : commentaire 'canonical-skip:$1:<raison>' sur la ligne)." >&2
  exit 2
}

emit_and_exit() {
  local local_hook="$project/.claude/hooks/dispatch-expert.local.sh"
  # shellcheck disable=SC1090
  [ -f "$local_hook" ] && source "$local_hook"
  if [ "${#HINTS[@]}" -gt 0 ]; then
    jq -n --arg c "$(printf '%s\n' "${HINTS[@]}")" \
      '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
  fi
  exit 0
}

# Lignes qui matchent (ERE ; 2e argument « i » = insensible à la casse), hors lignes canonical-skip.
hits() {
  local flags="-nE"
  [ "${2:-}" = i ] && flags="-niE"
  grep "$flags" -- "$1" "$file" 2>/dev/null | grep -v 'canonical-skip:' || true
}
has() { [ -n "$(hits "$@")" ]; }
first() { printf '%s\n' "$1" | head -1 | cut -c1-140; }

# Noms qui désignent un secret ou un élément de session.
SENSITIVE='token|jwt|passw|secret|credential|refresh|session|auth[^o]'
Q="[\"'\`]"
LOCAL_HOSTS='http://(localhost|127\.0\.0\.1|0\.0\.0\.0|10\.0\.2\.2|10\.0\.3\.2|192\.168\.|\[::1\])'
NON_API_HTTP='w3\.org|xmlns|schemas\.|purl\.org|ns\.adobe\.com'

# Règle commune : nom de variable EXPO_PUBLIC_* qui désigne un secret (inliné en clair dans le bundle).
check_expo_public() {
  local h
  h=$(hits 'EXPO_PUBLIC_[A-Z0-9_]*(SECRET|PASSWORD|PASSWD|PRIVATE|SERVICE_ROLE|ACCESS_TOKEN|AUTH_TOKEN|REFRESH_TOKEN)')
  [ -z "$h" ] || block "env-P0" "variable EXPO_PUBLIC_* nommée comme un secret dans $rel ($(first "$h")) : tout EXPO_PUBLIC_ est inliné en clair dans le bundle. Garder le secret côté serveur ou dans une variable EAS 'secret' sans préfixe EXPO_PUBLIC_. Invoquer 'mobile-security'."
  h=$(hits 'EXPO_PUBLIC_[A-Z0-9_]*(_KEY|TOKEN)' | grep -vE 'PUBLISHABLE|PUBLIC_KEY|ANON_KEY' || true)
  [ -z "$h" ] || hint "[env-P1] $rel : $(first "$h") — vérifier que cette valeur est publique par conception (clé restreinte au bundle id, clé publishable). Sinon, la sortir du bundle."
}

# Les fichiers de config passent avant le code : app.config.ts est aussi un .ts.
case "$rel" in
  # ---------- Config native / Expo / EAS ----------
  app.json|app.config.ts|app.config.js|app.config.mjs|app.config.cjs|eas.json|*AndroidManifest.xml|*Info.plist|*.plist)
    h=$(hits 'usesCleartextTraffic["'\'']?[[:space:]]*[:=][[:space:]]*["'\'']?true')
    [ -z "$h" ] || block "net-P0" "usesCleartextTraffic: true dans $rel ($(first "$h")) : autorise le HTTP en clair sur Android en release. Retirer (le client de dev Expo gère déjà Metro). Invoquer 'mobile-security'."
    h=$(hits 'NSAllowsArbitraryLoads["'\'']?[[:space:]]*[:=][[:space:]]*true')
    if [ -z "$h" ] && has '<key>NSAllowsArbitraryLoads</key>'; then
      h=$(grep -n -A1 '<key>NSAllowsArbitraryLoads</key>' "$file" | grep '<true/>' || true)
    fi
    [ -z "$h" ] || block "net-P0" "NSAllowsArbitraryLoads = true dans $rel ($(first "$h")) : désactive App Transport Security. Utiliser HTTPS ou une exception NSExceptionDomains ciblée. Invoquer 'mobile-security'."
    h=$(hits 'authToken["'\'']?[[:space:]]*:[[:space:]]*["'\''][^"'\''$]{8,}')
    [ -z "$h" ] || block "env-P0" "authToken en clair dans $rel ($(first "$h")) : secret de build versionné. Le fournir via une variable EAS 'secret' (ex. SENTRY_AUTH_TOKEN). Invoquer 'mobile-security'."
    check_expo_public
    has 'allowBackup["'\'']?[[:space:]]*[:=][[:space:]]*["'\'']?true' \
      && hint "[sec-P1] $rel : android allowBackup true — mettre false si l'app stocke des données sensibles (MASVS-STORAGE-2)."
    hint "[sec] Invoquer 'mobile-security' sur $rel (réseau, permissions, secrets de build). Changement natif : build EAS requis, pas livrable en OTA."
    ;;

  # ---------- Code applicatif JS/TS ----------
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)
    case "$rel" in
      *.test.*|*.spec.*|*__tests__/*|*__mocks__/*|*.config.js|*.config.cjs|*.config.mjs|metro.config.*|babel.config.*) is_test=1 ;;
      *) is_test=0 ;;
    esac

    if [ "$is_test" = 0 ]; then
      # Stockage non chiffré d'un secret de session (MASVS-STORAGE-1).
      h=$(hits "(AsyncStorage\.(setItem|multiSet|mergeItem)|[a-z_]*(storage|mmkv|kv)\.(set|setString|setItem))\([[:space:]]*[^,)]*($SENSITIVE)" i | grep -vi 'secure' || true)
      [ -z "$h" ] || block "storage-P0" "secret de session écrit dans un stockage non chiffré dans $rel ($(first "$h")). Utiliser expo-secure-store (setItemAsync avec keychainAccessible: WHEN_UNLOCKED_THIS_DEVICE_ONLY). Invoquer 'mobile-security'."

      # Secret ou session journalisé (MASVS-CODE / OWASP A09).
      h=$(hits "console\.(log|info|debug|warn|error|trace)\(.*([,(][[:space:]]*|\\$\{)[A-Za-z0-9_\$.?]*(token|jwt|password|passwd|secret|authorization|credential)" i)
      [ -z "$h" ] || block "log-P0" "token, mot de passe ou header Authorization passé à console.* dans $rel ($(first "$h")). Retirer le log ou ne journaliser qu'un identifiant non sensible. Invoquer 'mobile-security'."

      # URL d'API en clair (MASVS-NETWORK-1).
      h=$(hits "${Q}http://" | grep -vE "$LOCAL_HOSTS" | grep -viE "$NON_API_HTTP" || true)
      if [ -n "$h" ]; then
        api=$(printf '%s\n' "$h" | grep -iE 'api|base|url|endpoint|host|server|origin|fetch|axios|ws' || true)
        [ -z "$api" ] || block "net-P0" "URL d'API en http:// dans $rel ($(first "$api")) : trafic en clair interceptable. Utiliser https:// (seuls localhost / 10.0.2.2 en dev sont tolérés). Invoquer 'mobile-security'."
        hint "[net-P1] $rel : lien http:// ($(first "$h")) — passer en https:// si possible."
      fi
    fi

    check_expo_public

    # ---------- Conseils (non bloquants) ----------
    case "$rel" in
      app/*|src/app/*)
        hint "[arch] Invoquer 'mobile-architect' (écran fin, garde Stack.Protected, routes typées, seam de données) sur $rel."
        has '(fetch\(|axios\.)' \
          && hint "[arch-P1] $rel : appel réseau direct dans une route — passer par le client API unique (seam) et un hook de query."
        ;;
    esac
    if has 'useLocalSearchParams|useGlobalSearchParams|Linking\.(parse|openURL|getInitialURL)|redirectSystemPath'; then
      hint "[sec] $rel lit des paramètres de route / deep link : valider par schéma, restreindre les redirections à une allowlist interne (open redirect). Invoquer 'mobile-security'."
    fi
    if has 'SecureStore|AsyncStorage|MMKV|Authorization|refresh|expo-auth-session|AppleAuthentication|LocalAuthentication'; then
      hint "[sec] $rel touche la session, le stockage ou l'authentification. Invoquer 'mobile-security' (keychainAccessible, refresh single-flight, purge sur 401, PKCE/nonce)."
    fi
    if has '<ScrollView' && has '\.map\('; then
      hint "[perf-P1] $rel : ScrollView + .map() — FlashList/FlatList si la liste n'est pas bornée. Invoquer 'mobile-performance'."
    fi
    if has "import[[:space:]]*\{[^}]*\bImage\b[^}]*\}[[:space:]]*from[[:space:]]*['\"]react-native['\"]"; then
      hint "[perf-P1] $rel : Image de react-native — préférer expo-image (cachePolicy, placeholder, recyclingKey)."
    fi
    if has "queryKey:[[:space:]]*\[[[:space:]]*['\"]"; then
      hint "[arch-P1] $rel : query key littérale — utiliser la factory de clés du domaine (invalidations cohérentes)."
    fi
    if has 'FlatList|FlashList|useSharedValue|Animated\.|useQuery|useInfiniteQuery|staleTime|gcTime'; then
      hint "[perf] Invoquer 'mobile-performance' (virtualisation, thread UI, staleTime/gcTime) sur $rel."
    fi
    ;;

  # ---------- Variables d'environnement ----------
  .env|.env.*|*/.env|*/.env.*)
    check_expo_public
    ;;
esac

emit_and_exit
