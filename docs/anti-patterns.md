# Anti-Patterns Critiques

> Liste exhaustive des patterns interdits et leur correction.
> Les **7 critiques** (P0/P1) sont aussi rappelés dans `CLAUDE.md`.
> Tout nouveau anti-pattern découvert en review doit être ajouté ici.

## Convention de tagging

Les lignes du tableau référencent parfois des entités ou services du projet d'origine (MyProject). Pour un projet bootstrapped depuis le cookbook, **traduire** ces références via :

- `<PRIMARY_MODELS>` (ex : `Document`, `Gallery`, etc.) → l'entrée correspondante dans `CLAUDE.md §5 PRIMARY_MODELS` du projet hôte
- `StorageService` / `BrandingService` / `BookingOtpService` → le module équivalent du projet (storage seam, branding loader, otp service — cf `CLAUDE.md §1 Stack` + `§5 Glossary`)

Les patterns **génériques** (sans nom propre projet) s'appliquent tels quels à n'importe quel projet AdonisJS / Node / TS.

---

## Sécurité & Multi-tenant

| Anti-Pattern | Solution | Sévérité |
|-------------|----------|----------|
| `auth.user.id` dans les queries | `effectiveUserId` (middleware team) | P0 |
| `drive.use()` direct dans controller | Le module storage seam du projet (`.upload()` / `.delete()` / `.getStream()` — cf CLAUDE.md §5) | P0 |
| URL S3 brute dans `JSON.stringify()` / `response.json()` | Pré-signer dans le controller via le storage seam (`.getSignedUrl()`) | P0 |
| `invoice.attachmentUrl` brut dans response/view | `<StorageService>.getSignedUrl(url, '1h')` dans le controller | P0 |
| `<PRIMARY_MODELS>.query()` sans `.whereNull('deletedAt')` ET sans `.where('userId')` (cf CLAUDE.md §5) | Toujours les deux filtres (soft delete + tenant). Canonical : `<Model>.forTenant(uid)` static method | P0 |
| Portal query sans `userId` | `.where('userId', ownerId)` même avec `contactId` (defense-in-depth) | P0 |
| Upload route avec quota check SUR SEULEMENT UN path (legacy/chunked/presigned mais pas tous) | Sweep complet : **chaque path d'upload** doit avoir `middleware.quota({ resource: 'storage' })` (galleries) ou `'transfer_storage'` (transfers). Audit 2026-05-28 (commit b017d328) : `uploadPhotos` legacy + `chunkedUpload init/complete` n'avaient pas le check → user avec storage 4.7/2 Go pouvait continuer à uploader si client tombait sur le legacy path. Règle : `grep middleware.quota` doit retourner une ligne par chemin d'upload distinct dans le même service. | P0 |
| Contract/Document store avec uniquement `quota({ feature: 'X' })` sans `quota({ resource: 'documents' })` | Les contracts sont stockés dans `documents` (count vers documents quota). Feature gate ≠ count quota. Toujours combiner les deux sur les routes `contracts.store` + `contracts.import` (commit b017d328) | P0 |
| File upload route sans `middleware.antivirus()` | Toute route acceptant un `MultipartFile` user-facing doit avoir l'antivirus middleware (MIME magic bytes + ClamAV si CLAMAV_HOST défini). Audit 2026-05-28 (commit 1925780b) : 6 routes corrigées (services attachments, expenses, bookings cover, catalog cover, white-mark logo/favicon). Public uploads (questionnaire) restent throttle-only mais doivent être limités. | P1 |
| `crypto.timingSafeEqual(a, b)` sans vérification préalable des longueurs | `a.length !== b.length \|\| !timingSafeEqual(a, b)` — throws RangeError si longueurs différentes → 500 au lieu de 401 | P1 |
| `formAction` CSP sans domaines externes OAuth/paiement | Ajouter `https://connect.stripe.com` pour Stripe OAuth — un redirect de form vers un domaine non listé = blocage navigateur silencieux | P1 |
| Confirm avec apostrophe dans JS inline | `data-confirm` attribute + `$el.dataset.confirm` | P1 |
| Sentry capture des 4xx (validation, route-not-found) | Filter via `beforeSend` (commit ae9f90bd) — `E_VALIDATION_ERROR`, `E_HTTP_EXCEPTION`, `E_ROUTE_NOT_FOUND`, `E_UNAUTHORIZED_ACCESS`, `E_INVALID_CREDENTIALS` → skip. Sentry monitore uniquement 5xx + PaymentException + AuthorizationException + jobs (CLAUDE.md §1). | P2 |

---

## Edge.js / Alpine.js

| Anti-Pattern | Solution | Sévérité |
|-------------|----------|----------|
| `@input`, `@blur`, `@click`, `@change`, `@dragover`, `@drop` Alpine dans fichiers inclus via `@include` | `x-on:input`, `x-on:blur`, `x-on:click`, `x-on:change`, `x-on:dragover`, `x-on:drop` — Edge interprète `@` comme préfixe de directive dans les fichiers `@include`'d et strips silencieusement l'attribut. Les modificateurs (`.prevent`, `.stop`) aggravent en provoquant un crash 500 au parse. Règle : **toujours `x-on:` dans un partial**. Audit 2026-05-19 : 4 partials corrigés (commit `d23b5fd`) — `_attachments.edge`, `_tasks.edge`, `_cookie_consent.edge`, `_upgrade_modal.edge`. | P0 |
| `\|\|` dans expression **`@each`** (`@each(x in list \|\| [])`) | `@each` a son propre mini-parseur qui tokenise `\|` comme pipe → erreur `not a valid expression for the @each tag`. Solution : `@if(list) @each(x in list) ... @end @endif`. Les `\|\|` dans `{{ }}`, `@if()`, `@let()` passent (parseur JS standard). | P0 |
| `@set(name, value)` pour déclarer une locale Edge | `@set` est réservé à la **mutation** d'une property existante, pas à la déclaration. Silently fail → variable undefined à la prochaine lecture. Utiliser `@let(name = value)` | P1 |
| Apostrophe `'` dans une string JS inline dans `x-text` | L'apostrophe ferme prématurément la string. `x-text="{ 'KEY': 'L\\'envoi' }[code]"` crashe avec `Unexpected identifier 'envoi'`. Solutions : (a) splitter en plusieurs `<template x-if="code === 'KEY'">` qui rendent `t()` côté Edge ; (b) utiliser des guillemets doubles HTML-encodés `&quot;...&quot;` (le navigateur décode → JS reçoit `"..."` → l'apostrophe à l'intérieur est libre). Exemple corrigé : `x-text="value + &quot; aujourd'hui&quot;"` au lieu de `'... aujourd\\'hui'`. | P0 |
| `@if(condition) checked @endif` inline dans un attribut HTML multi-line | Le tokenizer Edge casse avec `Unexpected token " checked @endif"` quand la directive est sur sa propre ligne entre deux attributs. Utiliser un ternaire dans `{{ }}` : `{{ condition ? 'checked' : '' }}`. Idem pour `selected`, `disabled`, `readonly`. Le `@if` block fonctionne entre balises mais pas dans le contexte d'attributs HTML splittés. | P0 |
| `t('key.with.{var}').replace('{var}', value)` post-appel | i18n ICU rejette le placeholder non résolu — `The intl string context variable "var" was not provided`. Passer la variable directement à `t()` : `t('key.with.{var}', { var: value })`. La string de traduction utilise la syntaxe ICU `{var}`, jamais de post-processing JS sur le retour. | P1 |
| `@layout.user({ ... })` sans `@end` final dans la vue | `@layout.X` est un block tag — Edge attend un `@end` à la fin du fichier. Sans lui, parse error `Unclosed tag layout.user` → 500 au render avant même d'atteindre le contenu. Ajouter `@end` en dernière ligne du fichier (juste après le dernier `</div>` du body). Idem pour `@layout.public`, `@layout.app`, etc. | P0 |
| `@let(name = (arg) => expr)` arrow function dans une vue Edge | Edge accepte la syntaxe au parse mais le runtime ne peut pas invoquer une arrow function stockée via `@let` — `name(...)` crashe à l'évaluation. Solutions : (a) précomputer le résultat dans plusieurs `@let` séparés (`@let(flagOk = cond)` puis `{{ flagOk ? classOk : classKo }}`) ; (b) passer la fonction depuis le controller dans `view.render('...', { fn: ... })` ; (c) extraire dans une partial Edge `@!component('partials/_pill', { ok })`. | P1 |
| `{{{ JSON.stringify() }}}` dans `x-data` | `<script type="application/json">` | P1 |
| `<template x-if>` **à l'intérieur** d'un `<button>` ou élément interactif | `x-show` — `x-if` détruit/recrée le DOM, provoque `Cannot set properties of null (setting '_x_dataStack')` sur les éléments liés au scope parent | P1 |
| Variable Edge serveur dans expression Alpine (`x-show`, `x-if`, `:class`) | Injecter comme littéral statique via `{{ variable ? 'true' : 'false' }}` ou inclure dans `x-data` via `t()` server-side | P1 |
| `$t('key')` dans expression Alpine (`x-text`, `:placeholder`) | `$t` n'est pas une magic property Alpine — créer un objet `labels: { ... }` dans `x-data` peuplé côté serveur via `t()` | P1 |
| `<` dans Alpine `:class` ou `:style` | `>=` avec ternaire inverse (Edge encode `<` en `&lt;`, casse Turbo) | P1 |
| `@slot('scripts')` | Inclure les scripts directement dans la page | P1 |
| `@include` avec `$props` | `@!component` | P1 |
| `Alpine.data()` inline `<script>` | Module Vite (`resources/js/`) + enregistrement `app.js` | P1 |
| `x-data="{ ...maFactory(), extra: 1 }"` (spread d'une factory qui expose des **getters**) | Le spread d'objet **invoque chaque getter une fois** et copie sa **valeur de retour** comme propriété statique — le getter n'est PAS préservé, donc il ne se recalcule jamais. Symptôme : un `get fooJson()` reste figé à sa valeur initiale (ex: `"[]"`) quel que soit le state. Détecté sur `google_drive.edge` (les dossiers sélectionnés étaient soumis comme `selectedFolders="[]"` car `get selectedFoldersJson()` était gelé). **Fix** : ne jamais spread une factory à getters. Déclarer les props supplémentaires DANS la factory et utiliser `x-data="maFactory()"` directement (commit branche `dreamy-johnson`). | P0 |
| CDN version flottante | Pinner version exacte (Alpine `@3.14.9`, Turbo `@8.0.4`) | P2 |
| `<span x-show="...">@svg('lucide:X')</span>` sur **une seule ligne** | edge-iconify enregistre `@svg` comme tag `block: false, seekable: true` — le tag ne déclenche QUE s'il est en début de ligne (premier caractère non-whitespace). Mid-line → output littéral `@svg(...)` dans le HTML rendu. Casser sur 3 lignes : `<span x-show="...">\n  @svg(...)\n</span>`. Audit 2026-04-22 : 57 occurrences corrigées dans 9 fichiers (commit `d81e4c94`). Repro minimal : `edge.render('<span>@svg(...)</span>')` → texte brut, `edge.render('<span>\n  @svg(...)\n</span>')` → SVG correct. | P1 |
| `{{ description }}` (échappé) sur un champ WYSIWYG/Tiptap qui peut contenir `<p></p>` | Tags HTML deviennent visibles littéralement (ex: `<p></p>` au-dessus du prix dans une carte upsell). 3 stratégies : (a) carte/résumé line-clamp → `{{ stripHtml(description) }}` (Edge global, miroir client de `app/helpers/strip_html.ts`) ; (b) page détail riche → `{{{ sanitizeHtml(description) }}}` ; (c) Alpine `x-text` → strip côté backend dans la sérialisation JSON : `import { stripHtml } from '#helpers/strip_html'` puis `description: stripHtml(entity.description)`. | P1 |
| Clé JSON dupliquée dans un fichier `resources/lang/{locale}/*.json` (ex: `"activity"` défini 2 fois) | `JSON.parse` natif garde silencieusement la **dernière** occurrence — la première est shadowed sans warning. Symptôme : toutes les sous-clés de la 1ère définition affichent `translation missing: <locale>, <namespace>.<sub>` côté UI alors qu'elles existent visuellement dans le fichier. Audit 2026-05-21 : 2 sections `"activity"` dans `galleries.json` FR + EN (commit `f42077c9`) → 10 sous-clés inaccessibles. Vérification : `node -e "JSON.parse(require('fs').readFileSync('resources/lang/fr/X.json'))"` valide la syntaxe mais ne détecte PAS les dupliqués. Pour audit complet, parser via une lib qui throw sur duplicate (`json-source-map`, `ajv` avec strict, ou `jq 'paths(scalars) as $p \| $p \| join(".")' \| sort \| uniq -d`). | P1 |
| `@svg('lucide:NOM-INEXISTANT')` au render du layout user | **edge-iconify crash au rendu** → 500 sur TOUTE page qui utilise le layout (dashboard, transfers, contacts, …). `node ace build` ne détecte PAS (les icons sont résolus à l'exécution, pas au build). Audit 2026-05-23 : `lucide:camera-plus` (n'existe pas, alternative `lucide:image-plus`) et `lucide:loader-2` (n'existe pas, alternative `lucide:loader-circle`) dans `_mobile_upload_fab.edge` → 500 prod sur `/transfers` (commit `6c2b80b0`). **Check obligatoire** avant tout commit ajoutant un icon : `node -e "console.log(!!require('@iconify-json/lucide/icons.json').icons['NOM'])"`. Idéal : helper de scan automatique au build qui parse tous les `@svg('lucide:...')` du repo et vérifie l'existence dans `@iconify-json/lucide/icons.json`. Pour vérifier la liste complète : `node -e "console.log(Object.keys(require('@iconify-json/lucide/icons.json').icons).filter(k => k.includes('SUFFIX')))"`. | P0 |
| `{{var}}` Mustache au lieu de `{var}` ICU dans `resources/lang/{locale}/*.json` | AdonisJS i18n parse les messages via `@formatjs/icu-messageformat-parser` — la syntaxe ICU n'accepte que les **simples** accolades. `{{var}}` est invalide → `MALFORMED_ARGUMENT` au premier appel `i18n.t(key, { var: ... })`. Le parse est **lazy** : tant qu'aucun caller ne passe de params, la clé reste silencieusement broken (rendue littéralement `{{var}}` côté UI). Au premier appel avec params → crash 500. Audit 2026-05-24 : 9 clés affectées (`admin.json` impersonation/search, `site.json` slugNormalized, `galleries.json` expirations/selection) → 500 prod sur impersonation banner + admin search (commit `3a96428a`). Sweep : `grep -rn '{{[a-zA-Z_]*}}' resources/lang/` doit retourner **zéro**. Pluriels ICU : `{count, plural, one {# item} other {# items}}` (toujours accolade externe simple). | P0 |
| `@!component('components/pagination', { paginator: <p> })` au lieu de `data:` | Le composant lit `data.currentPage` ligne 1 sans fallback. Passer `paginator:` → `data` undefined → `Cannot read properties of undefined (reading 'currentPage')` → 500 au render de la page. Audit 2026-05-24 : 5 callers (`bookings`, `admin/audit_log`, `admin/platform_invoices`, `finances/expenses`, `finances/payments`) ont été migrés vers `data:` (commit `3a96428a`). Sweep : `grep -rn "components/pagination.*paginator:" resources/views/` doit retourner **zéro**. Convention unique : toujours `{ data: <paginator> }`. | P1 |
| `@let(X = ...)` déclaré dans `@if(condition)` puis référencée par scope d'un `@include` HORS du @if | Edge résout les variables du scope parent au moment du @include, même si le partial n'utilise pas X explicitement. Si la condition est false, X n'existe pas → `X is not defined` crash 500. **3 récurrences prod sur sidebar.edge** : `contactsLevel` (commit `3373810c`), `billingUrlActive` (commit `0ae8846f`), `isRevenusSectionActive` + 4 autres (commit `b67eca08`). Pattern d'origine : `@let` à L70 dans `@if(roleId === 1)` qui ferme à L265, mais `@include('partials/_sidebar_plan_row')` à L477 hors du block. **Règle** : toute @let référencée par le scope d'un @include qui suit doit être hoistée HORS des @if conditionnels au-dessus. Si la déclaration nécessite un guard, faire `@let(X = condition ? expr : null)` plutôt que mettre tout le @let dans le @if. Audit pro-actif : `grep -nE "^\s+@let\(" partials/sidebar.edge` puis vérifier que chaque déclaration est avant TOUS les @include. | P0 |
| `<input type="hidden" name="_method" value="DELETE" />` body input pour AdonisJS method spoofing | Le pattern body-input est silencieusement ignoré en prod AdonisJS 6, malgré ce que dit la doc (`request.input('_method')` lit body+QS en théorie). Symptôme : POST /contracts/X retourne 404 E_ROUTE_NOT_FOUND alors que la route DELETE /contracts/:id existe. **Pattern qui marche** : `?_method=DELETE` en query string via `route(name, params, { qs: { _method: 'DELETE' } })` ou concat manuel `action="{{ url }}{{ url.includes('?') ? '&' : '?' }}_method=DELETE"`. Audit 2026-05-29 (commit `1b74961a`) : `_doc_action_menu.edge` utilisait body-input → fix QS. Sweep : `grep -rn 'name="_method"' resources/views/` doit retourner **zéro**. `allowMethodSpoofing: true` dans `config/app.ts` requis (déjà set). | P0 |
| `x-data="{ open: true }"` wrapper cosmetic collapse Alpine sur children qui consomment scope parent | Alpine 3 `x-data` SHADOW totalement le parent scope — les variables parent (ex: `coverMode`/`sectionNavMode`) deviennent inaccessibles dans children. Symptôme : `x-show="parent"` dans un enfant du wrapper devient toujours false. **Fix** : utiliser `<details>` HTML natif pour collapse cosmétique. `<details><summary>Titre</summary>content</details>` — 0 Alpine, 0 shadow, accessible clavier + screen reader natif. Idéal pour density gate §17.6 (masquer section derrière accordion). | P1 |
| `push(...newItems)` avec Alpine array reactive → `arr = arr.concat(newItems)` remplacement | Array replacement re-render `x-for` complet (destroy + recreate DOM). Symptôme : scroll browser reset à 0 après pagination infinite scroll galerie. **Fix** : mutation in-place `arr.push(...newItems)` (Alpine détecte via Proxy sans re-render du DOM entier). | P1 |
| ZIP archiver loop qui `archive.append(await stream)` sans buffer materialize | `archiver` avec stream direct sur 10+ photos → OOM/crash mémoire (streams parallèles empilés). **Fix** : materialize via `getBytes()` séquentiel, helper canonique `appendPhotoBufferToArchive`. Boucle for/await sur getBytes → append Buffer. Corrigé prod : Lionel bulk 639 files transfer archive job. | P0 |
| `document.querySelector(...)` ne traverse pas `<template>` (DocumentFragment) | Alpine `<template x-teleport>` / `x-if` / `x-for` = DocumentFragment détaché — querySelector standard rate le contenu. Symptôme : lazy-loader DOM (app.js `collectMatchingImports`) ne charge pas les scripts référencés dans un template. **Fix** : scanner explicitement `tpl.content.querySelector(...)` pour éléments dans templates. | P1 |
| `EXPORT_URL_TTL = '7d'` const declaration variable — scan-secu step 40 miss | Ancienne regex `getSignedUrl(..., 'Nh')` détecte call site literal, mais rate `const X = '7d'` puis `getSignedUrl(..., X)`. **Fix scan** : regex étendu `'Nh' N≥2 \| 'Nd' \| expiresIn ≥ 10000` + skip context 5L via commentaire `canonical-skip:presigned-ttl <raison>` (v0.3+ cookbook). Nouveau site legit (ex: PWA manifest, RGPD export) = ajouter comment, PAS modifier scan. | P1 |
| Toggle switch UI sans `role="switch"` / `aria-checked` / touch 44px / `focus-visible` | `<button>` toggle bind `:title` (non lu screen reader) + `h-4 w-7` (16×28px < WCAG 44px min) + hover only. Fix : `role="switch"` + `:aria-checked` binding + wrapper `min-h-[44px] min-w-[44px] focus-visible:ring-2`. Le visuel toggle reste dans un `<span>` interne. | P0 |
| `JSON.stringify()` dans `<script type="application/json">` avec user-controlled data | Anti-XSS incomplet — user input contenant `</script>` termine early le script tag. **Fix** : helper `safeJson()` qui escape `<`/`>`/`&` (edge.global) avant sérialisation. Ex Adonis : `edge.global('safeJson', v => JSON.stringify(v).replace(/</g, '\\u003c'))`. | P0 |
| `animate-pulse` / `animate-spin` / `animate-*` Tailwind sans préfixe `motion-safe:` | WCAG 2.3.3 reduced-motion : utilisateurs `prefers-reduced-motion` reçoivent quand même l'animation. **Fix** : `motion-safe:animate-pulse` / `motion-safe:animate-spin`. Sweep batch : `sed -i 's/animate-spin/motion-safe:animate-spin/g'`. | P1 |
| Modal custom `<div>` sans focus trap / focus restore au close | Focus s'échappe modal au Tab, ne revient pas au trigger button au close. **Fix** : `<dialog>` HTML5 natif (focus trap + restore automatiques) via composant wrapper canonique (ex: `editorial/_dialog` avec directive Alpine `x-editorial-dialog`). | P0 |
| Input `text-sm` (14px) sur mobile → auto-zoom iOS au focus | iOS Safari zoom automatique quand input font-size < 16px. Break UX scroll. **Fix** : `text-base` (16px) sur tous inputs mobile, ou `text-[16px]` explicite. | P0 |
| Formulaire multi-champs sans `beforeunload` guard | Cancel/refresh perd données silencieusement. **Fix Alpine** : `x-data="{ dirty: false }"` + `x-on:input="dirty = true"` + `x-on:beforeunload.window="if (dirty && !submitting) $event.returnValue = ''"`. | P0 |

---

## Base de données & ORM

| Anti-Pattern | Solution | Sévérité |
|-------------|----------|----------|
| N+1 queries | `preload()` Lucid dans la query d'origine | P1 |
| `.load()` après query initiale | `preload()` dans la query d'origine | P1 |
| `await save()` en boucle for/forEach | Batch update raw SQL ou `Model.createMany()` | P1 |
| `Task.create()` en boucle | `Task.createMany([...])` — 1 INSERT au lieu de N | P1 |
| 8+ requêtes parallèles par handler | Consolider en raw SQL avec sous-requêtes | P2 |
| `preload('photos')` sans `.limit()` | Paginer (80 init + 50/batch via endpoint JSON) | P2 |
| Interpolation `${variable}` dans raw SQL | Paramétrer avec `?` — JAMAIS d'interpolation | P0 |
| Interpolation `${id}` dans raw SQL CASE/WHERE | `WHEN ? THEN` avec paramètres binds | P0 |
| `pool.min > 0` dans config/database.ts | `pool.min: 0` (scale-to-zero Neon) | P2 |
| `pool.max > 10` avec Neon pooler | `pool.max: 10` (pgBouncer gère le reste) | P2 |
| `idleTimeoutMillis < 20000` | `30000` minimum | P2 |
| `Knex .enum('col', [v1, v2])` puis ajout d'une 3e valeur côté enum TypeScript sans migration `ALTER CONSTRAINT` | `.enum()` PG génère un CHECK constraint strict (`x_col_check CHECK (col IN ('v1', 'v2'))`). Ajouter `v3` côté TS enum + validator sans étendre le CHECK → 500 violation Postgres au INSERT/UPDATE. Migration idempotente : `ALTER TABLE x DROP CONSTRAINT IF EXISTS x_col_check; ALTER TABLE x ADD CONSTRAINT x_col_check CHECK (col IN ('v1', 'v2', 'v3'));`. Pattern : `1795000000001_add_pending_status_to_subscriptions.ts` ou `1900000000610_add_pin_to_galleries_access_type.ts`. Audit : tout enum `bookings.status`, `documents.type`, `tokens.type`, `galleries.access_type`, `subscriptions.status`, `services.status` est concerné. | P0 |
| `withCount('tasks')` dans une query Lucid puis lecture `$extras.tasksCount` (camelCase) dans la vue | Lucid stocke le résultat d'un `withCount('relation')` en **snake_case** automatiquement → `$extras.tasks_count`. Pour un nom personnalisé, utiliser `.withCount('tasks', q => q.as('completedTasksCount'))` — avec `.as()`, le nom est préservé verbatim. Sans `.as()`, **toujours lire en snake_case**. Cf `_board_service_card.edge` commit `54794b1`. | P2 |
| `request.input('field') \|\| fallback` quand un champ peut être soumis vide intentionnellement (ex: reset d'une FK) | `request.input()` retourne `null` (pas `undefined`) quand le champ est **absent** du formulaire — donc `\|\|` traite `''` (soumis vide) et `null` (absent) de la même façon et écrase le "aucun" choisi par l'utilisateur. Solution : `request.has('field') ? request.input('field') \|\| null : fallback` — `has()` détecte si le champ était présent dans le corps de la requête. Cf `bookings_controller.ts` `createService()` commit `d2e2ce1`. | P1 |
| `DateTime.now().toFormat('yyyy-MM-dd HH:mm:ss')` pour comparaison WHERE sur un timestamp | `DateTime.now()` retourne la TZ locale serveur ; `.toFormat('yyyy-MM-dd HH:mm:ss')` produit une string **sans offset** → Postgres l'interprète comme heure locale alors que les timestamps Lucid sont stockés en UTC. Drift silencieux : tokens / invitations / sessions qui apparaissent valides après leur expiration (ou inversement). Canonical : `DateTime.utc().toSQL()!` (UTC explicite, ISO avec offset, `.toSQL()` est l'API Lucid-friendly). Pattern de référence : `BookingOtpService`. Fix initial 2026-05-27 (commit `73bc701f`) sur 13 fichiers auth/portal/team — reste à sweeper : `subscription_service`, `workflow_service`, `home_dashboard_service`, `forgot_password_controller` (cleanup query). Scan : `grep -rnE "DateTime\.now\(\)\.toFormat\(['\"]yyyy-MM-dd HH:mm:ss['\"]\)" app/`. Le format date-seule `'yyyy-MM-dd'` (filenames, exports CSV) reste OK — c'est exclusivement le format timestamp qui pose problème. CI : check G de scan-secu.sh step 22. Opt-out : `// canonical-skip:datetime-utc:<raison>`. | P1 |
| `whereNull('expiresAt')` comme fallback "valide" dans un WHERE de token/invitation | Un token sans `expiresAt` ne doit **jamais** être considéré comme valide indéfiniment — c'est une erreur de saisie au mieux, une faille d'élévation au pire. La création de tokens doit toujours fixer `expiresAt`, la lecture ne doit accepter QUE `expiresAt > now`. Pattern correct : `.where('expiresAt', '>', DateTime.utc().toSQL()!)` — pas de `whereNull` OR. Audit 2026-05-27 (commit `73bc701f`) : 5 sites corrigés (activation, reset password ×2, user_email_service, activation_reminder). Exception légitime : `shop_product_access_service` et `gallery_selection_share_service` où `whereNull` exprime "accès permanent" by-design (pas un bug). | P1 |
| **Sur-optimisation prématurée de `whereILike('col', '%X%')`** sur table user-scopée | Le `user_id` filter (B-tree index canonique) narrow agressivement avant le ilike scan. Cas typique MyProject : <5000 docs/contacts/galleries/services par photographe → seq scan ilike = 5-20ms, acceptable. Ne PAS migrer vers pg_trgm + GIN tant qu'un user n'a pas dépassé 10k rows dans la table cible — pg_trgm ajoute maintenance (extension Postgres + index ~5x table size) sans bénéfice perceptible en-dessous. Re-évaluer si métriques pg_stat_statements remontent une query whereILike > 100ms p95. Exception : queries cross-user (admin search, platform_invoices admin) — gardent leur perf actuelle, latence admin acceptable. Décision documentée 2026-05-29 task #7. | (note : P3 si jamais nécessaire) |

---

## Cache Redis & Storage S3

| Anti-Pattern | Solution | Sévérité |
|-------------|----------|----------|
| TTL Redis fixe indépendant de `expiresIn` (ex: `23 * 60 * 60`) | `cacheTtlFromExpiry(expiresIn)` — TTL = `expiresIn - 5min` | P1 |
| `getSignedUrl(key, '1h')` avec TTL Redis > 1h | TTL Redis < `expiresIn` — sinon URL périmée servie depuis cache | P1 |
| Constante TTL Redis indépendante de `expiresIn` | Toujours dériver le TTL dans le storage seam du projet | P1 |

---

## Design System

| Anti-Pattern | Solution |
|-------------|----------|
| `bg-primary` seul sur bouton | Gradient `bg-gradient-to-r from-[#004ac6] to-[#2563eb]` + `shadow-lg shadow-blue-500/20` |
| `rounded-lg border border-stone-200` sur carte | `rounded-2xl bg-white dark:bg-stone-900` (tonal, pas de bordure) |
| `rounded-lg border` sur input/select | `border-0 border-b border-stone-200` (bottom-border only) |
| `text-xs font-medium` sur label formulaire | `text-[10px] font-bold tracking-[0.15em] uppercase font-display` |
| `<h1>` sans label curator au-dessus | Ajouter `<p class="text-xs font-semibold uppercase tracking-[0.15em]">` avant le titre |
| `#000000` / `text-black` | `text-stone-900 dark:text-white` |
| `shadow-md` / `shadow-lg` standard | `shadow-[0_8px_30px_rgba(0,0,0,0.04)]` ambient |
| `border border-{amber\|red\|green\|blue}-{200\|300}` sur banner notification | `bg-{X}-50 ring-1 ring-inset ring-{X}-200/60 dark:ring-{X}-800/60` (charte 2026-05-28, ~30 occurrences corrigées commits 173e9d00 + bb0c5b8f). Le pattern `ring-inset` remplace **toutes** les bordures colorées sur les banners flash + success/error/warning. |
| Data list container sans `shadow-sm` | `<div class="overflow-hidden rounded-2xl bg-white shadow-sm dark:bg-stone-900">` — pattern canonique contacts/index:245. Audit 2026-05-28 (commits 0a46a931, f669758d) : 18 data list pages restaurées. UX prompt audit antérieur avait supprimé le relief par méprise. |
| Submit CTA `font-semibold uppercase tracking-wider` (legacy) | `font-display font-bold uppercase tracking-wider` + `hover:brightness-110` (pas `hover:shadow-xl`). Pattern unifié contacts/index:145 (commit bb0c5b8f docs edit). |
| Inline quota-check long boolean (`quotaSummary && .quotas && .quotas.X && !.unlimited && .percentage >= 80`) | Helper Edge global `quotaWarningLevel(quotaSummary, key)` retourne `'none' \| 'warning' \| 'danger'` (commits 67610597, bd52f8f5). DRY 4× sidebar + dashboard home. |
| Inline locked banner amber duplicated entre pages | Composant `components/_feature_locked.edge` (commit 061ac4ca) — variants `inline` + `card`, props `messageKey` + `messageParams`. Helper Edge `canUseResource(quotaSummary, key)` pour la check. Sweep 6 pages. |
| `@let(X = ...)` dans `@if`/`@elseif` branche puis références dans `@include` du `@else` | `@let` est block-scoped → ne traverse pas les branches `@if/@elseif/@else`. Hoist au scope parent (commit 3373810c sidebar). Symptôme prod : Sentry `X is not defined` au runtime. |

## UI Density (PRODUCT.md "the photo leads" / Axe 6 cognitive restraint)

> **Source unique** : `docs/ux-audit-prompt.md` Axe 6. Ces règles sont vérifiables et bloquent le merge (P0).

| Anti-Pattern | Pourquoi | Solution |
|-------------|----------|----------|
| Page de config avec **> 4 sections visibles d'un coup** | Mur d'options → user scrolle pour comprendre l'utile vs l'avancé | Grouper en 2-3 accordions (progressive disclosure), 1 ouvert par défaut |
| **Browser chrome mock** autour d'une preview live (3 ronds + URL pill + ext-link icon dans un cadre rounded-2xl shadow) | Décoratif, "browser dans le browser", cache la photo | Preview pleine largeur, sans card chrome, l'URL est dans le header de la page |
| Section header avec **`01 / 02 / .. 07 /`** numérotation chapitrée | Chrome chapitré décoratif | Juste un label uppercase `text-[10px] font-bold uppercase` |
| **Icon square 7×7** (`inline-flex size-7 ... bg-stone-100`) systématique à gauche de chaque section header | Chrome répété sans valeur | Drop ; le label suffit |
| **> 2 niveaux** de toggles imbriqués dans une même card | Charge cognitive forte, user ne sait plus quel parent contrôle quoi | Aplatir ou utiliser un accordion sub-level |
| **Header de page > 1 ligne** ou titre+description répétant la sidebar | Doublon avec la nav (Axe 4 redondance) | Header 1 ligne : status + URL/contexte + Save. Titre dans le breadcrumb seulement |
| **Pulsing badge décoratif** ("● LIVE", "● Aperçu", glassmorphism gratuit) toujours visible | Bruit visuel sans info | Drop OU afficher 2s après une modification |
| **5+ boutons preset** inline (focal points, palettes, ratios) toujours visibles | Pas premium, mur d'options | Réduire à 1 "Réinitialiser" + interaction directe sur l'aperçu |
| **`{{{ JSON.stringify() }}}` dans `x-data=""`** comme dépôt de données | XSS risk + lecture difficile | `<script type="application/json" id="...">` + `JSON.parse()` dans `init()` |
| **Form 8+ sections avec `space-y-16`** sans grouping | L'espace ne compense pas la densité | Accordions ou tabs |

**Test de lecture 60s** : un user qui voit l'écran pour la 1ère fois doit pouvoir répondre en 60s à
1. "Qu'est-ce que je fais ici en priorité ?"  
2. "Quel est mon état actuel ?"
3. "Où je vais après ?"

Si une réponse demande > 60s → P0.

**Skill `/ux-review <page>`** applique ces règles + les 6 axes systématiquement. À invoquer AVANT d'ajouter une nouvelle section à un écran de config existant.

---

## Logique Métier

| Anti-Pattern | Solution |
|-------------|----------|
| `merge()` avec `undefined` | `{ ...payload }` de Vine.js |
| `COALESCE` manquant sur `emitted_at` | `COALESCE(d.emitted_at, d.created_at)` |
| Montant sans `formatCurrency()` | Toujours `formatCurrency(amount, code)` |
| Enum brut affiché | Toujours `t('documents.types.*')` |
| Taille fichier en dur (Go/Mo/Ko) | `formatFileSize(bytes)` helper global |
| `ImageService.generateVariants()` sans watermark | Passer `watermark` param si `gallery.watermarkEnabled` |
| `content-visibility: auto` sur items de galerie | Supprimé — disparition items hors viewport avec Alpine lazy rendering |
| Table `suppliers` séparée | `contacts` avec `isSupplier=true` (+ `iban`, `paymentTerms`) |
| Champ texte libre `invoice.supplier` | `invoice.supplierId` FK vers Contact |
| Table `gallery_presets` (ancien) | `content_library` avec `category: 'gallery_preset'` |
| Enum `category` hardcodé dans `catalog_items` | `service_type_id` FK vers `service_types` |
| `formatCurrency(value, undefined)` dans show.edge | Passer `defaultCurrencyCode` depuis le controller |
| Devis envoyé irréversible | `QUOTE_TRANSITIONS[PENDING]` inclut `DRAFT` (recall) |
| Fallback devise hardcodé `'XAF'` | Fallback → `'EUR'` ; résolution : user_currencies default → company.currency → fallback |
| Admin sans moyen de créer un abonnement | `POST /subscriptions/grant` provider `MANUAL` |
| `Subscription.create()` sans `paymentProviderId` | La colonne est NOT NULL sans default — toujours fournir `paymentProviderId: 'manual-grant'` (ou l'ID provider) | P1 |
| `activeTab: 'lightroom'` ou `'google-calendar'` | Utiliser `'integrations'` (nav unifié) |
| `activeTab: 'billing'` ou route `settings.billing` | `'payments'` / `route('settings.payments.index')` |
| Modifier `siteSetting.slug` sans alias | `INSERT INTO site_setting_slug_aliases` avant merge |
| **`store()` booking : try/catch qui swallow checkout failure → fallthrough gratuit silencieux** | Pre-flight `hasActivePaymentProvider(userId)` + branching déterministe : `mustCheckout` (strict fail → CANCELLED + flash) vs `trySoftCheckout` (add-ons uniquement, fallback OK). Voir `PublicBookingController.store()`. |
| `Token.create({ type: 'BOOKING_OTP' })` sans avoir étendu le check constraint `tokens_type_check` | Chaque nouveau type `TOKEN_TYPES.*` doit être ajouté au CHECK via migration `ALTER CONSTRAINT`. Sinon 500 silencieux sur insert (violation contrainte Postgres). Cf migration `1900000000340_add_booking_otp_to_tokens_type`. |
| Nouvelle colonne JSONB sans `prepare/consume` sur le model Lucid | Lucid serialize mal les objets JSON en base sans les helpers. Toujours écrire `@column({ prepare: v => v ? JSON.stringify(v) : null, consume: v => typeof v === 'string' ? JSON.parse(v) : v })`. Cf `Booking.nativeAddonsSnapshot`. |
| Fetch `POST` public depuis Alpine avec `Content-Type: application/json` | Shield CSRF check n'attrape pas toujours le token en body JSON. Utiliser un helper `postForm(url, fields)` qui envoie `application/x-www-form-urlencoded` avec `_csrf` dans le body **ET** `X-CSRF-TOKEN` + `X-XSRF-TOKEN` + `X-Requested-With` en headers. Cf `public-booking-flow.js`. |
| URL publique `/book/:uuid` brut | Réutiliser `site_settings.slug` comme handle lisible avec fallback UUID + alias via `resolveHandle()`. Voir `business-rules.md` §Réservations. |
| `phone_input` component avec dropdown country code sans valeur par défaut | Affiche `+__` confus au client. Préférer `<input type="tel" placeholder="+237 6 00 00 00 00" inputmode="tel" autocomplete="tel">` simple sauf si dropdown nécessaire. |
| `.catch(() => {})` sur une promesse fire-and-forget (email, notif, cache invalidation) | `import { swallow } from '#helpers/swallow'` puis `.catch(swallow('op_name'))`. Log Pino `warn` structuré avec `err` + tag identifiant — sans ça les échecs (SMTP down, Redis down, webhook timeout) sont invisibles jusqu'à ce qu'un user se plaigne. Cf `app/helpers/swallow.ts`. | P1 |
| `await res.json()` après `fetch` / `fetchWithRetry` non protégé par try/catch | Si le serveur retourne du HTML (redirect CSRF, page 500, maintenance) au lieu de JSON, `.json()` lance `SyntaxError: Unexpected token '<'` qui n'est pas catchée par le bloc qui protège la requête réseau. Conséquences : état Alpine `uploading: true` bloqué, UI gelée. Toujours séparer la protection réseau de la protection parsing : `var data; try { data = await res.json() } catch (e) { this.error = labels.serverError; this.uploading = false; return }`. Cf `transfer-create.js` `submitTransfer()` (commit `107ba27`). | P1 |
| `window.confirm()` dans une action inline sur mobile (suppression, validation) | `confirm()` natif déclenche un dialog système qui, au retour, repositionne le scroll en haut de la page sur iOS et certains Android. Conséquences : l'utilisateur perd sa position après suppression d'un item dans une longue liste. Solution : confirmation inline Alpine — `pendingDeleteId` setter qui affiche des boutons ✓/✕ directement sur l'item, sans aucun dialog natif. `cancelDelete()` pour annuler, `confirmDelete()` pour exécuter le fetch. Cf `gallery/interaction.js` + `show.edge` (commit `107ba27`). | P2 |
| Controller > 300 lignes / Service > 400 lignes / Template > 800 lignes | Splitter par sous-domaine. CLAUDE.md §14. Check CI automatique via `node scripts/check-file-sizes.js` — baseline grandfathered dans `scripts/file-size-baseline.json`, toute nouvelle violation bloque le commit. | P2 |
| `private async resolveHandle(handle)` dupliqué dans 2+ controllers | Extraire dans `app/controllers/_helpers/` (ex: `resolve_booking_handle.ts`, `public_gallery_helpers.ts`). Import partagé via `#controllers/_helpers/*`. | P2 |
| `mail.sendLater(sendFn)` pour un email lifecycle (booking confirmé/annulé/expiré) qui doit partir immédiatement | `sendLater` empile dans la queue BullMQ. Si le worker externe est down ou en retard, le mail reste coincé sans feedback visible côté client. Lifecycle critique → `mail.send(sendFn)` synchrone : le controller attend ~1-2s mais le mail part en direct + toute erreur SMTP remonte dans les logs. `sendLater` reste OK pour les emails non-bloquants : reminders, review requests, notifications scheduled, OTP. Cf `BookingEmailService.sendClientConfirmed/Cancelled/AbandonedSlot` (commit `698f46a7`). | P1 |
| Page publique re-affichable (confirmation booking, success page paiement, gallery shared link) qui dépend uniquement d'un `session.flash()` one-shot pour son contenu | Refresh / bookmark / retour plus tard → flash perdu (par design AdonisJS) → page se vide silencieusement, le client voit un titre orphelin sans card, ni CTAs, ni meta. Solution : relayer l'identifiant via query param signé `?ref=<token>` où le token est un champ déjà persisté en DB avec ≥ 32 bytes d'entropie (ex: `bookings.confirmation_token`, `transfers.access_token`). Lookup à 2 sources dans le controller : flash en priorité (premier landing), fallback `request.qs().ref` + guard sur le scope (e.g. `bookingTypeId` doit matcher pour éviter les liens croisés). Cf `PublicBookingConfirmationController.confirmation()` (commit `9f9399b2`). | P1 |
| `GalleryDownloadToken` scope `favorites` pour livrer un ZIP au client absent | Le scope `favorites` lit `GalleryFavorite` filtré par `session.sessionId` — non persistent cross-device, donc le client ouvrant le mail download depuis son téléphone (autre session) reçoit "No photos in this selection". Solution : scope `selection:<id>` qui lit `GallerySelection.photoIds` (UUID[] persisté en DB). Cross-device garanti. Cf `GalleryPublicDownloadController.download()` + `GalleryClientEmailService.dispatchSelectionReceipt()` (commit `253fbb21`). | P1 |
| Constante TTL/délai/seuil hardcodée dans un service (`const REFERRAL_BONUS_DAYS = 60`, `const HOLD_MINUTES = 15`, etc.) | Tout paramètre métier doit être configurable côté admin sans déploiement. Stocker dans `platform_settings` (singleton) ou `user_settings.customFields` (per-tenant). Lire avec fallback `?? <default>`. Cf `platform_settings.referral_bonus_days` + `SubscriptionService.computeReferralBonusDays()` (commit `0f038fc9`). | P2 |
| Auto-création d'une colonne unique sans index partiel `WHERE col IS NOT NULL` | Index unique standard `(user_id, col)` rejette les NULL multiples si une colonne devient nullable plus tard pour back-compat. Toujours utiliser `CREATE UNIQUE INDEX ... WHERE col IS NOT NULL` pour autoriser les bookings/users legacy avec NULL tout en garantissant l'unicité sur les nouvelles entrées. Cf `1900000000780_add_booking_code_to_bookings`. | P2 |
| `apply()` button pour activer un programme parrainage qui devrait être ouvert à tous | Frottement onboarding. Préférer auto-création au signup (`AffiliateService.autoCreateForSignup`) avec backfill paresseux côté controller (`if (!affiliate) await ...; affiliate = await ...`) pour les users créés avant la migration auto. Pattern aligné avec `project_referral_philosophy`. Cf commit `0f038fc9`. | P2 |

---

## Tiptap / Éditeur

| Anti-Pattern | Solution |
|-------------|----------|
| `StarterKit` sans `link: false, underline: false` | StarterKit v3.20+ inclut Link/Underline nativement — désactiver si importés séparément |
| `$nextTick` pour init Tiptap dans composant parent | `setTimeout(300)` — Tiptap a besoin de temps pour s'initialiser |
| Blueprint Handlebars `{{subtotalHT}}` mais mapping `amountExclTax` | Exposer les deux noms + formater via `Intl.NumberFormat` |

---

## Formulaires HTML

| Anti-Pattern | Solution |
|-------------|----------|
| Hidden + checkbox HTML — parsé en string seule | `qs` produit `["false","true"]` — sanitizer : `Array.isArray() ? .at(-1) : value` |
| Ligne document sans `unit` ni `description` | Propager depuis le catalogue via `catalog-item-selected` event |

---

## Workflow Agentic

### Anti-pattern P1 — Double-discipline gratuite

**Symptôme** : Claude invoque à la fois un skill projet ET son équivalent superpowers générique pour la même tâche.

**Exemples concrets** :
- `/feature` + `brainstorming` (le skill projet `/feature` invoque déjà `brainstorming` en interne)
- `code-reviewer` subagent + `requesting-code-review` skill (le subagent projet REMPLACE le skill superpowers)
- `/pre-pr` + `verification-before-completion` (sauf cas `gh pr create` qui combine `/pre-pr` + `finishing-a-development-branch`)

**Pourquoi c'est mauvais** :
- Coût tokens × 2 sur la même réflexion
- Friction utilisateur (Claude pose 2 fois les mêmes questions)
- Risque d'incohérence si les 2 outils proposent des verdicts contradictoires

**Solution** : appliquer la **règle d'or routage** définie dans [`docs/claude-config/superpowers-integration.md`](claude-config/superpowers-integration.md) §3 :

> Si un skill projet existe pour le contexte, il PRIME sur l'équivalent superpowers générique. Les skills superpowers s'invoquent uniquement quand aucun skill projet ne couvre le contexte (gap pur).

**Détection en review** : si un commit ou une session mentionne 2 skills couvrant le même axe, c'est un anti-pattern. Voir matrice §4 de `superpowers-integration.md` pour les correspondances exhaustives.

---

> **Règle d'ajout** : tout nouveau pattern découvert en code review → ajouter immédiatement ici + l'entry courte dans `CLAUDE.md §13`.
