# `/feature` — Matrice de dispatch des experts (pack Expo)

Référence chargée par `/feature` (step 7), `/multi-agent` et `/pr`. Décrit quel expert invoquer selon le scope d'une feature dans une app Expo / React Native.

Note : les experts marqués **projet-specific** sont OPTIONNELS. Le pack n'installe que les experts génériques de la stack ; un projet peut ajouter les siens dans `.claude/agents/` (design system, paiement in-app, domaine métier…). Le skill vérifie `.claude/agents/<name>.md` et n'invoque que ceux qui existent.

## Architecte (toujours invoqué si du code applicatif est touché)

| Si la feature touche... | Invoquer |
|---|---|
| Routes `app/**`, `_layout.tsx`, groupes, navigation | `mobile-architect` |
| `features/**`, `api/**`, hooks de query, query keys, stores | `mobile-architect` |

## Cross-cutting

| Si la feature touche... | Invoquer |
|---|---|
| Auth, session, client HTTP, stockage (`SecureStore`, AsyncStorage, MMKV, SQLite) | `mobile-security` |
| Deep links, `+native-intent`, `useLocalSearchParams` réutilisés pour naviguer, WebView | `mobile-security` |
| `app.json` / `app.config.*`, `eas.json`, `.env*`, permissions, config plugins | `mobile-security` |
| Listes, animations, images, démarrage (`_layout` racine, splash, polices) | `mobile-performance` |
| Options de cache TanStack (`staleTime`, `gcTime`, persistance, offline) | `mobile-performance` (+ `mobile-security` si persistance) |

## UI / UX

| Si la feature touche... | Invoquer |
|---|---|
| Nouvel écran, composants, accessibilité, conventions iOS/Android | `frontend` (core) |
| Design system du projet | `<design-system-expert>` **projet-specific** si présent |

## Domain (projet-specific — optionnels)

| Si la feature touche... | Invoquer si présent dans .claude/agents/ |
|---|---|
| Paiement / achats in-app / abonnements | expert domain du projet — modèle : `docs/templates/example-domain-agent.md` |
| Règles métier propres au produit | expert domain du projet |

## Tests

| Si la feature... | Invoquer |
|---|---|
| Ajoute une logique critique (session, sync offline, calculs) | `qa` (core) |

## Final gate (avant `git commit`)

| Toujours, avant commit non-trivial | Invoquer |
|---|---|
| ≥ 2 fichiers OU ≥ 50 lignes OU touche `app/**`, `api/**`, auth, `app.json`, `eas.json` | `mobile-code-reviewer` (final) |

## Cas combinés fréquents

### Nouvel écran de données (liste + détail)
1. `mobile-architect` (route, seam, query key factory)
2. `mobile-performance` (liste virtualisée, images, staleTime)
3. `frontend` (UX, accessibilité, états vides/erreur)
4. `mobile-code-reviewer` (avant commit)

### Auth / session (login, refresh, logout, OAuth)
1. `mobile-security` (SecureStore, refresh single-flight, purge 401, PKCE/nonce)
2. `mobile-architect` (garde `Stack.Protected`, seam)
3. `qa` (concurrence des 401, expiration)
4. `mobile-code-reviewer`

### Deep link / notification qui ouvre un écran
1. `mobile-security` (validation des params, allowlist de redirection, `+native-intent`)
2. `mobile-architect` (routes typées, garde)
3. `mobile-code-reviewer`

### Ajout d'un module natif ou changement de config
1. `mobile-security` (permissions, réseau, secrets de build)
2. `mobile-architect` (config plugin, pas d'édition de `ios/`/`android/`)
3. `mobile-code-reviewer` (build EAS requis, pas d'OTA)

## Convention d'invocation

- Architecte + cross-cutting : peuvent tourner **en parallèle** (2-4 subagents).
- Domain : un seul à la fois.
- `mobile-code-reviewer` : toujours **en dernier**, après application des findings.
