# architecture.md — Architecture globale du projet

> **Destinataire** : `back-architect` (mode adonisjs) ou `architect` (mode none) subagent, + toi/team.
> **Format** : diagramme + couches + patterns transverses + seams clés. Pas de doc exhaustive — le code reste source de vérité.

---

## 1. Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────┐
│  <Frontend layer — Edge/React/Vue/…>                        │
│    Templates + composants + design system                   │
├─────────────────────────────────────────────────────────────┤
│  <API layer — controllers + validators>                     │
│    HTTP surface, auth middleware, effectiveUserId injection │
├─────────────────────────────────────────────────────────────┤
│  <Services layer — business logic>                          │
│    1 service = 1 responsabilité, ≤400L, helpers _helpers/  │
├─────────────────────────────────────────────────────────────┤
│  <Data layer — models + migrations>                         │
│    Lucid ORM, Neon Postgres, S3 storage, Redis cache        │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Stack technique

| Couche | Techno | Version | Motivation |
|---|---|---|---|
| Runtime | Node.js | 20 LTS | ESM natif, perf, écosystème |
| Framework | `<AdonisJS 6 / Next 15 / …>` | `<X.Y>` | `<pourquoi ce choix>` |
| ORM | `<Lucid / Prisma / …>` | | |
| DB | `<Postgres / MySQL / …>` | | |
| Cache | `<Redis / …>` | | |
| Storage | `<S3 / Cloudflare R2 / …>` | | |
| Frontend | `<Edge / React / Vue / …>` | | |
| Queue | `<BullMQ / …>` | | |
| Email | `<Resend / Mailtrap / …>` | | |
| Auth | `<AdonisJS auth / Auth.js / …>` | | |

---

## 3. Couches et responsabilités

### 3.1 Controllers

- **Rôle** : traduire HTTP ↔ business
- **Limites** : ≤300L (voir CLAUDE.md §14)
- **Contient** : validation Vine, orchestration service, réponse
- **NE contient PAS** : logique métier, requêtes DB directes

### 3.2 Services

- **Rôle** : business logic pure
- **Limites** : ≤400L, 1 responsabilité
- **Contient** : orchestration models, règles métier, transactions
- **NE contient PAS** : HTTP, rendering

### 3.3 Models

- **Rôle** : représentation DB + relations Lucid
- **Contient** : columns, relations, scopes, hooks lifecycle
- **NE contient PAS** : business logic complexe (→ service)

### 3.4 Templates (frontend Edge)

- **Limites** : ≤800L (voir CLAUDE.md §14)
- **Split** : partials `_component.edge` réutilisés
- **Alpine directives** : `x-on:click` (pas `@click` dans partials — voir anti-patterns.md)

---

## 4. Patterns transverses

### 4.1 Multi-tenant

- Chaque requête business filtrée par `effectiveUserId` (middleware `team`)
- **Jamais** `auth.user.id` directement — voir `docs/security-multitenant.md` + `security-multitenant` agent
- IDOR prevention : `.where('userId', effectiveUserId).firstOrFail()`

### 4.2 Fire-and-forget

- Helper `swallow` pour `.catch()` silencieux avec log structuré
- Import : `import { swallow } from '#helpers/swallow'`
- Usage : `.catch(swallow('operation_name'))`

### 4.3 Soft-delete

- Modèles sensibles (Documents, Invoices, etc.) : soft-delete via `deletedAt`
- Query scope global qui exclut par défaut

### 4.4 Signed URLs

- Fichiers privés S3 servis via URL signée temporaire (1h)
- Helper : `StorageService.getSignedUrl(key)` — voir `docs/storage-s3.md`

---

## 5. Seams clés

Points d'extension où le code est explicitement pluggable :

| Seam | Fichier | Extension |
|---|---|---|
| Hook dispatch expert local | `.claude/hooks/dispatch-expert.local.sh` | Ajouter hints projet-specific |
| Domain agents | `.claude/agents/<domain>-*.md` | Ajouter experts stack-metier |
| Feature spec | `docs/features/<name>.md` | Toute nouvelle feature |
| Anti-patterns | `docs/anti-patterns.md` | Enrichi à chaque lesson learned |

---

## 6. Cross-refs

- CLAUDE.md §3 — Naming
- CLAUDE.md §8 — Workflow nouvelle feature 6-step
- CLAUDE.md §14 — Limites tailles fichiers
- `docs/anti-patterns.md` — Catalogue patterns interdits
- `docs/security-multitenant.md` — Isolation tenant
- `docs/database-neon.md` — ORM + queries
- `docs/storage-s3.md` — Fichiers privés
- `docs/design-system.md` — Charte UI
