# anti-patterns.md — Catalogue des patterns interdits

> **Destinataire** : tous les experts subagents + toi.
> **Sources** : lessons learned réelles du projet + CLAUDE.md §13 + `scan-secu.sh` steps.
> **Format** : par domaine → pattern interdit → pourquoi → alternative correcte. Toujours cite le fichier + issue/incident si applicable.

---

## Sécurité

### `auth.user.id` direct dans query business

**Interdit** :
```ts
const invoices = await Invoice.query().where('userId', auth.user.id)
```

**Pourquoi** : casse l'isolation multi-tenant. Si un admin agit "on behalf of" un autre user (feature team), `auth.user.id` retourne l'admin, pas le tenant réel.

**Correct** :
```ts
const invoices = await Invoice.query().where('userId', effectiveUserId)
```

**Cross-ref** : `docs/security-multitenant.md`, `scan-secu.sh` step 22A, hook `dispatch-expert.sh` (block P0).

---

### IDOR — pas de `.where('userId', X)` sur fetch by id

**Interdit** :
```ts
const invoice = await Invoice.find(params.id)  // n'importe qui peut lire n'importe quelle facture
```

**Correct** :
```ts
const invoice = await Invoice.query()
  .where('userId', effectiveUserId)
  .where('id', params.id)
  .firstOrFail()
```

---

### `drive.use()` direct

**Interdit** : bypass la couche `StorageService` (auth, signed URLs, quota).

**Correct** : `StorageService.upload(...)`, `StorageService.getSignedUrl(key)`.

---

### `.catch(() => {})` silencieux

**Interdit** : swallow silencieux perd les logs → debugging impossible en prod.

**Correct** :
```ts
import { swallow } from '#helpers/swallow'
await risky().catch(swallow('operation_name'))
```

---

## ORM / DB

### `preload` vs `load` sur collection déjà chargée

Voir `docs/database-neon.md` + `data-access-reviewer` subagent.

### Raw SQL avec template literal `${…}`

**Interdit** : injection SQL.

```ts
Database.rawQuery(`SELECT * FROM users WHERE id = ${userId}`)  // ❌
```

**Correct** : paramètres `?`.

```ts
Database.rawQuery('SELECT * FROM users WHERE id = ?', [userId])
```

---

### `await save()` dans une boucle

**Interdit** : N queries séquentielles, bloque pendant N × latency.

**Correct** : `Model.createMany(records)` (une seule query).

---

## Migrations

### Pas de `IF NOT EXISTS` sur ADD COLUMN

**Interdit** : re-run migration en dev casse.

**Correct** :
```ts
if (await this.schema.hasColumn('users', 'phone') === false) {
  this.schema.alterTable('users', (t) => t.string('phone'))
}
```

---

### `NOT NULL` sans `DEFAULT` sur table existante

**Interdit** : migration échoue si rows existent.

**Correct** : DEFAULT explicit ou migration en 3 étapes (add nullable → backfill → alter NOT NULL).

---

### Extension enum TS sans ALTER CONSTRAINT

**Interdit** : le CHECK constraint Postgres reste à l'ancien set de valeurs, les nouvelles insertions crashent.

**Correct** : migration qui `DROP CONSTRAINT` puis `ADD CONSTRAINT` avec le nouveau set.

---

## Templates Edge

### `{{{ JSON.stringify }}}` hors `<script type="application/json">`

**Interdit** : XSS.

**Correct** :
```edge
<script type="application/json" id="data">
  {{{ JSON.stringify(payload) }}}
</script>
```

Le JS lit `document.getElementById('data').textContent`.

---

### Directives `@click` dans un partial `_component.edge`

**Interdit** : Edge interprète `@` comme directive template, pas Alpine.

**Correct** : `x-on:click`.

---

### `@svg()` mid-ligne

**Interdit** : `edge-iconify` ne déclenche que début-de-ligne → output littéral en prod.

**Correct** : `@svg('icon-name')` sur sa propre ligne.

---

## i18n

### Syntax Mustache `{{var}}` dans lang JSON

**Interdit** : ICU MessageFormat attendu → crash `MALFORMED_ARGUMENT` runtime.

**Correct** : `{var}` (ICU).

---

## Architecture

### Controller > 300L / Service > 400L / Template > 800L

**Interdit** : voir CLAUDE.md §14 limits.

**Correct** : split en sub-controllers par domaine, extraire helpers vers `app/services/_helpers/`.

---

## Ajouter un anti-pattern

Format :
1. **Titre** : le pattern interdit en 1 ligne
2. **Interdit** : bloc code exemple
3. **Pourquoi** : conséquence concrète (bug, incident, régression) + cross-ref (incident date, PR)
4. **Correct** : bloc code alternatif
5. **Cross-ref** : docs / agent / scan-secu step / hook qui l'attrape
