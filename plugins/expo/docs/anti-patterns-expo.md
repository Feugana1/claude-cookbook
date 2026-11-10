# Anti-Patterns — pack Expo

> Catalogue des patterns interdits pour une app Expo / React Native (expo-router, TanStack Query, expo-secure-store) et leur correction.
> Complète `docs/anti-patterns.md` (convention de tagging, anti-patterns de workflow agentic).
> Source de vérité du hook `.claude/hooks/dispatch-expert.sh` et des steps scan-secu du pack (50 à 58).
> Tout nouvel anti-pattern découvert en review est ajouté ici (stack) ou dans `docs/anti-patterns.md` (générique).
> Doc Expo de référence : toujours la version du SDK du projet — https://docs.expo.dev/versions/latest/ (remplacer `latest` par `v<SDK>.0.0`).

Exception ponctuelle et justifiée à une règle grepée : commentaire `canonical-skip:<règle>:<raison>` sur la ligne (lu par le hook et les steps).

---

## Sécurité (OWASP MASVS)

| Anti-Pattern | Solution | Sévérité | Contrôle |
|---|---|---|---|
| Access/refresh token, mot de passe ou session dans `AsyncStorage`, MMKV non chiffré, SQLite, `localStorage` | `expo-secure-store` (`setItemAsync(key, value, { keychainAccessible: WHEN_UNLOCKED_THIS_DEVICE_ONLY })`) — MASVS-STORAGE-1 | P0 | hook `storage-P0`, step 50 |
| `SecureStore.setItemAsync` sans `keychainAccessible` | Préciser l'option : `*_THIS_DEVICE_ONLY` empêche la migration vers un autre appareil via sauvegarde | P1 | step 50 |
| Cache TanStack persisté (`PersistQueryClientProvider`) sans filtre | `dehydrateOptions.shouldDehydrateQuery` excluant session, profil et toute PII | P1 | step 50 |
| `EXPO_PUBLIC_*SECRET*`, `*_PASSWORD`, `*_PRIVATE*`, `*_SERVICE_ROLE*`, `*_ACCESS_TOKEN` | `EXPO_PUBLIC_` est inliné en clair dans le bundle : garder le secret côté serveur ou dans une variable EAS `secret` non préfixée | P0 | hook `env-P0`, step 51 |
| `EXPO_PUBLIC_*_KEY` sans vérifier la nature de la clé | Clé publique par conception uniquement (publishable, anon, restreinte au bundle id / SHA-1) | P1 | hook (conseil), step 51 |
| Secret en clair dans `eas.json` (`build.<profil>.env`) ou `authToken` littéral dans `app.json` | `eas env:create --visibility secret` ; `process.env.X` dans `app.config.ts` | P0 | hook `env-P0`, step 57 |
| Base URL d'API en `http://` (hors `localhost` / `10.0.2.2` de dev) | `https://` partout en release ; base URL par environnement EAS | P0 | hook `net-P0`, step 52 |
| `usesCleartextTraffic: true` (app.json, `expo-build-properties`, AndroidManifest) | Retirer : le client de dev gère déjà Metro en local — MASVS-NETWORK-1 | P0 | hook `net-P0`, step 52 |
| `NSAllowsArbitraryLoads: true` | Retirer ; exception `NSExceptionDomains` ciblée et justifiée si un domaine tiers l'impose | P0 | hook `net-P0`, step 52 |
| `console.log(token)`, `console.log('x', user.password)`, header `Authorization` journalisé | Ne journaliser que des identifiants non sensibles ; scrubber Sentry (`beforeSend`, `beforeBreadcrumb`) | P0 | hook `log-P0`, step 53 |
| Plusieurs refresh concurrents sur une rafale de 401 | Verrou single-flight : une seule promesse de refresh partagée, les requêtes attendent puis rejouent | P0 | `mobile-security` |
| Refresh token non rotatif, ou refresh échoué sans purge | Rotation côté serveur ; échec → purge SecureStore + `queryClient.clear()` + écran de connexion | P0 | `mobile-security` |
| `router.replace(params.redirect)`, `<Redirect href={params.next}>`, `Linking.openURL(params.url)` sans validation | Schéma (zod/valibot) + allowlist de chemins internes (`startsWith('/')` et pas `//`) — open redirect, MASVS-PLATFORM-1 | P1 | hook (conseil), step 54 |
| Deep link entrant non filtré | `app/+native-intent.tsx` (`redirectSystemPath`) rejette les hôtes/chemins inconnus | P1 | `mobile-security` |
| OAuth sans PKCE / sans `state` / client secret dans l'app | `expo-auth-session` avec PKCE `S256`, `state` vérifié, `nonce` OIDC ; aucun client secret embarqué | P0 | `mobile-security` |
| Sign in with Apple sans nonce | Nonce aléatoire, hash SHA-256 envoyé à Apple, valeur brute vérifiée par le serveur | P0 | `mobile-security` |
| Biométrie = simple booléen local qui « déverrouille » la session | Biométrie qui protège l'accès au secret (`requireAuthentication` sur SecureStore) | P1 | `mobile-security` |
| Écran de secrets / paiement capturable | `usePreventScreenCapture()` (`expo-screen-capture`) sur ces écrans | P1 | `mobile-security` |
| `android.allowBackup` absent (défaut Android : `true`) avec données sensibles | `"android": { "allowBackup": false }` — MASVS-STORAGE-2 | P1 | step 58 |
| Sourcemaps / `dist/` commités | Ne pas versionner les exports ; sourcemaps envoyées à Sentry puis supprimées | P1 | step 57 |

---

## Architecture

| Anti-Pattern | Solution | Sévérité |
|---|---|---|
| `fetch` / `axios` direct dans un écran `app/**` ou un composant | Client API unique (base URL, auth, refresh, erreurs normalisées) consommé via des hooks de query par domaine | P0 |
| Redirection d'auth dans un `useEffect(() => router.replace(...))` écran par écran | Garde déclarative dans le layout : `<Stack.Protected guard={isSignedIn}>` | P1 |
| `href` construit par concaténation (`` `/contacts/${id}` ``) | Routes typées (`experiments.typedRoutes`) et objets `{ pathname: '/contacts/[id]', params: { id } }` | P1 |
| `queryKey: ['contacts', id]` littéral dispersé | Factory par domaine (`contactKeys.detail(id)`) et `queryOptions()` partagés entre `useQuery`, `prefetchQuery`, `invalidateQueries` | P1 |
| Réponse serveur copiée dans un store global / `useState` | TanStack Query est la seule source de l'état serveur ; le store client garde l'UI et les préférences | P1 |
| Mutation sans invalidation ciblée ni rollback optimiste | `onMutate` (snapshot) / `onError` (rollback) / `onSettled` (invalidate via factory) | P1 |
| Logique métier dans `app/**` (écran > 300 L) | Écran fin ; `features/<domaine>/{components,hooks,api}` | P1 |
| `npm i <module-natif>` | `npx expo install <module>` (version alignée sur le SDK) + config plugin | P1 |
| Édition manuelle de `ios/` ou `android/` en Continuous Native Generation | Config plugin ; `ios/`/`android/` régénérés par `prebuild` | P1 |
| Changement natif (plugin, permission, module) livré en EAS Update | Nouveau build + `runtimeVersion` ; l'OTA ne porte que du JS/assets | P0 |

---

## Performance

| Anti-Pattern | Solution | Sévérité |
|---|---|---|
| `ScrollView` + `.map()` sur une liste serveur non bornée | `FlashList` (ou `FlatList` avec `keyExtractor`, `getItemLayout` si hauteur fixe) | P0 |
| `useMemo` / `useCallback` / `memo` ajoutés partout avec React Compiler actif | Laisser le compilateur mémoïser ; respecter les règles de React | P2 |
| `renderItem` recréé à chaque render sans React Compiler | Mémoïser `renderItem` et les callbacks passés aux listes | P1 |
| Animation pilotée par `setState` à chaque frame | Reanimated (`useSharedValue`, `useAnimatedStyle`) sur le thread UI | P1 |
| `Image` de `react-native` pour des images distantes | `expo-image` avec `cachePolicy`, `placeholder`, `recyclingKey` en liste | P1 |
| Polices chargées au runtime, splash masqué trop tôt ou trop tard | Config plugin `expo-font` ; `SplashScreen.preventAutoHideAsync()` puis `hideAsync()` quand polices + session sont prêtes | P1 |
| `staleTime` absent (0) sur des données peu volatiles | `staleTime` explicite par domaine ; `gcTime` ≥ `maxAge` du persister | P1 |
| `focusManager` / `onlineManager` non branchés | `AppState` → `focusManager.setFocused`, NetInfo → `onlineManager.setOnline` | P2 |
| Import complet de grosses libs (`lodash`, `moment`, `import *`) | Imports ciblés ; vérifier avec `expo-atlas` | P2 |
