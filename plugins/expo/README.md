# Pack Expo — `cookbook-expo`

Pack optionnel de stack pour les apps mobiles **Expo / React Native** : Expo SDK 57+, nouvelle architecture React Native, expo-router, TanStack Query, expo-secure-store, EAS. Dépend de `cookbook-core`. Comptes à jour : `bash scripts/inventory.sh`.

Contenu : `agents/` (experts mobile stack-aware), `hooks/` (dispatcher de patterns P0), `scripts/scan-secu.d/` (steps mobiles + `lib-expo.sh`, helpers partagés), `docs/anti-patterns-expo.md`, `docs/dispatch-matrix.md`.

Doc de référence : toujours la doc Expo **versionnée** du SDK du projet (https://docs.expo.dev/versions/latest/, remplacer `latest` par `v<SDK>.0.0`). Les agents la consultent plutôt que de citer une API de mémoire.

## Installation

```bash
# Plugin
/plugin install cookbook-core@claude-cookbook
/plugin install cookbook-expo@claude-cookbook

# Bootstrap (exclusivité des rôles appliquée)
bash $COOKBOOK_DIR/bootstrap-claude.sh . --stack=expo
```

Le bootstrap copie ce README en `docs/claude-config/stack-expo.md`, les docs du pack dans `docs/`, le hook en `.claude/hooks/dispatch-expert.sh` (branché par `settings.hooks.json` à la création de `.claude/settings.json`) et les steps dans `scripts/scan-secu.d/`.

## Principe — mapping rôles ↔ stack

**On installe soit le rôle générique, soit son override stack, jamais les deux pour un même use case.** Un agent du pack **durcit** un rôle du core : il garde la règle d'or (sources chargées avant analyse, stay in scope, format P0 / P1 / Quick wins / Déjà correct, cite `file:line`) et ajoute les conventions mobiles. Chaque agent est autoportant (pas d'héritage littéral entre fichiers agents).

**Application de l'exclusivité** : uniquement par `bootstrap-claude.sh --stack=expo`. En installation plugin (`cookbook-core` + `cookbook-expo`), les deux jeux coexistent.

## Rôles du core remplacés par un agent du pack

| Rôle core | Remplacé par | Pourquoi le remplacer |
|---|---|---|
| `architect` | `mobile-architect` | Le rôle générique raisonne système/backend (API, microservices, 12-Factor). Une app Expo a ses propres décisions structurantes et vérifiables : arborescence expo-router, garde `Stack.Protected`, routes typées, seam d'accès aux données unique, factories de query keys, état serveur vs client, config plugins vs natif. |
| `security` | `mobile-security` | Le référentiel pertinent est OWASP **MASVS**, pas le Top 10 web : stockage Keychain/Keystore, `EXPO_PUBLIC_*` inliné dans le bundle, cleartext/ATS, deep links et open redirect, OAuth natif (PKCE, nonce Apple), journaux, capture d'écran, biométrie, secrets EAS. |
| `performance` | `mobile-performance` | Les métriques du rôle générique (Core Web Vitals, TTFB, EXPLAIN) ne s'appliquent pas ; le mobile se mesure en FPS JS/UI, TTI au démarrage, mémoire, taille du bundle Hermes, et se règle par virtualisation, Reanimated, expo-image, React Compiler, `staleTime`/`gcTime`. |
| `reviewer` | `mobile-code-reviewer` | Review PR-style qui orchestre les experts du pack et vérifie la cohérence propre à Expo (route ↔ layout ↔ query keys ↔ config native, OTA vs build natif). Même pattern que le pack AdonisJS. |

## Rôles du core conservés (aucun override)

`analyzer`, `frontend`, `product-strategist`, `qa`. `frontend` couvre déjà l'UX web **et mobile** (WCAG, conventions de plateforme, design system) : le pack ne le duplique pas, et n'ajoute donc pas de skill d'audit UX (le `/ux-review` du pack AdonisJS est propre aux templates Edge).

## Diagramme

```
                       core (agents/)                 pack expo (agents/)
Couche 0 strategic     product-strategist   ─────►    (conservé)
Couche 1 architect     architect            ─────►    mobile-architect      (durcit)
Couche 2 cross-cutting security             ─────►    mobile-security       (durcit, MASVS)
                       performance          ─────►    mobile-performance    (durcit)
Couche 4 UI            frontend             ─────►    (conservé : UX web + mobile)
Couche 5 final gate    reviewer             ─────►    mobile-code-reviewer  (durcit, orchestre)
Conservés tels quels : analyzer, qa
```

## Hook P0 — `hooks/dispatch-expert.sh`

`PostToolUse` sur `Edit|Write|MultiEdit`, même contrat que le hook du pack AdonisJS : exit 2 + `[hook:<classe>-P0] BLOCKED — …` sur un P0, sinon conseils d'experts en `additionalContext`. Exception justifiée : `canonical-skip:<classe>-P0:<raison>` en commentaire sur la ligne. Extension projet : `.claude/hooks/dispatch-expert.local.sh`.

| Classe | Fichiers | Pattern bloqué |
|---|---|---|
| `storage-P0` | `*.ts(x)`, `*.js(x)` | `AsyncStorage.setItem` / `storage.set` / MMKV avec une clé de token, refresh, session, secret, mot de passe |
| `log-P0` | idem | `console.*` qui reçoit ou interpole un token, mot de passe, secret, `Authorization` |
| `net-P0` | idem | URL d'API en `http://` (hors localhost, `10.0.2.2`, réseau local de dev) |
| `net-P0` | `app.json`, `app.config.*`, `AndroidManifest.xml`, `Info.plist` | `usesCleartextTraffic: true`, `NSAllowsArbitraryLoads: true` |
| `env-P0` | sources, `.env*`, `eas.json`, config | `EXPO_PUBLIC_*` nommé comme un secret (`SECRET`, `PASSWORD`, `PRIVATE`, `SERVICE_ROLE`, `ACCESS_TOKEN`…) ; `authToken` littéral dans la config |

## Steps scan-secu — `scripts/scan-secu.d/`

Numérotés à partir de 50 pour ne pas croiser le core ni les autres packs. Chaque step fait `SKIP` hors projet Expo (pas de dépendance `expo` dans `package.json`), respecte `--diff` (fichiers modifiés seulement ou `SKIP`) et `SECU_OFFLINE=1`.

| Step | Contrôle | Tier |
|---|---|---|
| 50 | secrets de session en stockage non chiffré (FAIL) ; SecureStore sans `keychainAccessible`, cache persisté sans filtre (WARN) | T1 · A02 |
| 51 | `EXPO_PUBLIC_*` nommé comme un secret (FAIL) ; `*_KEY` / `*TOKEN` publics à confirmer (WARN) | T1 · A02 |
| 52 | `usesCleartextTraffic`, `NSAllowsArbitraryLoads`, URL d'API `http://` (FAIL) ; autres `http://` (WARN) | T2 · A05 |
| 53 | `console.*` de token / mot de passe (FAIL) ; Sentry sans scrubber (WARN) | T2 · A09 |
| 54 | navigation pilotée par un paramètre de route sans validation visible — heuristique (WARN) | T2 · A01 |
| 55 | `npx expo install --check` (WARN si désaligné ; SKIP hors-ligne, délai `SECU_EXPO_TIMEOUT`) | T3 · Supply chain |
| 56 | `expo-doctor` si installé ou `SECU_EXPO_DOCTOR=1` (WARN) | T3 · Supply chain |
| 57 | secrets dans `eas.json` / `authToken` littéral, sourcemaps ou `dist/` commités (FAIL) | T2 · A05 |
| 58 | `android.allowBackup` absent ou `true` (WARN) | T2 · A05 |

Lancer seul depuis le cookbook : `SECU_EXTRA_STEPS_DIRS=plugins/expo/scripts/scan-secu.d bash plugins/core/scripts/scan-secu.sh --full`.

## Ajouter une stack

Procédure générique décrite dans [`plugins/adonisjs/README.md`](../adonisjs/README.md) (« Ajouter une stack ») : `plugins/<stack>/` + `pack.conf` + entrée `marketplace.json`, sans modifier le core. Ce pack la suit à l'identique. Deux packs peuvent livrer le même chemin installé (`.claude/hooks/dispatch-expert.sh`, `docs/dispatch-matrix.md`) : au changement de stack, le bootstrap met à jour le fichier au lieu de le retirer. `docs/dispatch-matrix.md` étant un fichier du projet (jamais écrasé), le comparer à la version du nouveau pack après un changement de stack.
