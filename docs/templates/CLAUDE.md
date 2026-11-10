# CLAUDE.md — Project Rules for AI Agents

> **Template** — copy to your project root as `CLAUDE.md` and edit §5
> Domain Model Glossary to match your domain. Agents + scan-secu.sh
> reference §5 as the single source of truth for tenant-scoped models.
>
> Bootstrap copies this verbatim ; you customize §5 once, never edit
> the agent files.

This file provides guidance to Claude Code and the cookbook sub-agents
when working on this project.

---

## 1. Stack

| Layer | Choice |
|---|---|
| Backend | (e.g. AdonisJS 6 / Express / NestJS) |
| ORM | (e.g. Lucid / Prisma / TypeORM) |
| DB | (e.g. PostgreSQL) |
| Cache / queue | (e.g. Redis + BullMQ) |
| Storage | (e.g. S3-compatible) |
| Templating | (e.g. Edge / Pug / React SSR) |
| Validation | (e.g. Vine / Zod) |

## 2. Naming conventions

| Element | Convention | Example |
|---|---|---|
| Tables DB | snake_case pluriel | `users`, `orders` |
| Colonnes DB | snake_case | `user_id`, `created_at` |
| Enum values | UPPER_SNAKE | `ACCEPTED`, `REFUNDED` |
| Models | PascalCase singulier | `User`, `Order` |
| Services | PascalCase + Service | `OrderService` |
| Routes | dot.notation | `orders.show` |

## 3. i18n

State the default + supported locales here, and the fallback rules.
Agents (a workflow/email domain agent, if you add one) check that any user-facing text goes
through the i18n layer.

## 4. Edge / Alpine

Only if your stack uses Edge.js + Alpine.js (Turbo Drive). Otherwise
delete this section ; the `edge-anti-patterns` sub-agent will skip.

---

## 5. Domain Model Glossary

> **The seam.** Every cookbook sub-agent that needs to enforce
> tenant-scoping, soft-delete, or RGPD rules references this table.
> Do NOT inline model names in agent prompts ; reference this section.

**PRIMARY_MODELS** — tenant-scoped entities. These are the models that :
- carry a `user_id` foreign key (multi-tenant isolation surface)
- typically need `deleted_at` soft-delete (RGPD grace period)
- power the `<Model>.forTenant(uid)` query seam pattern

| Model | Table | Soft-delete | Tenant col | RGPD class | Notes |
|---|---|---|---|---|---|
| (e.g.) Document | documents | ✅ `deleted_at` | `user_id` | Personal | NF525 immutable once SENT |
| (e.g.) Gallery | galleries | ✅ | `user_id` | Personal | S3 cleanup on purge |
| (e.g.) Contact | contacts | ⚠️ archived flag | `user_id` | Personal | RGPD export incl. archived |
| ... | ... | ... | ... | ... | ... |

**Cross-tenant entities** (intentionally not in PRIMARY_MODELS) :
- `User` (tenant root)
- `PlatformInvoice` (admin-facing aggregate)
- `(your own list)`

**Public-facing entities** (read by guests / token-auth, NOT tenant-scoped) :
- `(e.g. public booking pages, public gallery share tokens)`

### Configuration export for tools

Export the model list as a regex-compatible string for
`scripts/scan-secu.d/step-22-feature-divergence.sh` and similar :

```bash
# In your shell, or in scripts/scan-secu.env :
export PRIMARY_MODELS_RE="Document|Gallery|Contact|Order|Subscription"
```

Sub-agents that grep for these patterns will use the same variable.

---

## 6. Tenant-scope canonical patterns

Every read path on a PRIMARY_MODELS entry MUST chain :

```ts
.where('userId', effectiveUserId)   // multi-tenant isolation
.whereNull('deletedAt')              // soft-delete filter (if applicable)
```

**Canonical wrapper** — every project that adopts this cookbook is
expected to expose a static method on each PRIMARY_MODELS class :

```ts
class Document extends BaseModel {
  static forTenant(uid: string) {
    return this.query().where('userId', uid).whereNull('deletedAt')
  }
}
```

Then call sites become :

```ts
const docs = await Document.forTenant(effectiveUserId)
  .where('type', 'INVOICE')
  // ... caller's own predicates on top
```

scan-secu.sh step 22 enforces : every `<PRIMARY_MODELS>.query()` chain
that touches a terminator (.first / .firstOrFail / .paginate / .update /
.delete / .limit) MUST have both filters. Opt-out :
`// canonical-skip:soft-delete:<reason>` or `// canonical-skip:idor:<reason>`.

## 7. Migration rules

State your conventions here :
- `IF NOT EXISTS` for idempotency
- `DEFAULT` for any `NOT NULL` column on existing tables
- JSONB columns documented (shape, expected helpers)
- CHECK constraints extended (not just TS enum) when adding enum values

scan-secu.sh has a migration-reviewer pass — point it at your
`database/migrations/` directory.

## 8. Anti-patterns

The cookbook ships `docs/anti-patterns.md` with generic patterns.
Add project-specific anti-patterns here (1 line each, with link to
the docs/anti-patterns.md detail row when appropriate).

## 9. Token economy

- Subagent for mechanical, scoped-research or parallelizable work; the
  parent keeps reasoning and synthesis. Cheapest sufficient model:
  Haiku mechanical, Sonnet exploration, Opus tradeoffs. Each agent
  declares `model` + `effort` in its frontmatter.
- Code graph / index tool before grep + Read when the repo has one.
- PDFs: `pdftotext`, never Read (unless analysing images).
- Known file: read it directly, no search.
- Cache hygiene: pick model + MCP servers at session start; switching
  `/model` or toggling MCP mid-session rebuilds the cached prefix.
  `/clear` between unrelated tasks beats compacting earlier. Settings
  template: 1M context off, autocompact at 60%.
- Optional: `rtk init -g` compresses shell output; check with `rtk gain`.
- Keep this file lean: rules + pointers, details in referenced docs.
  Agent descriptions short (they load on every turn).

---

**Status** : Active — update §5 PRIMARY_MODELS whenever you add a new
tenant-scoped entity. The sub-agents read this section, not the model
files directly.
