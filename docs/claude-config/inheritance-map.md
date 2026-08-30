# Inheritance map — `roles/` ↔ `stacks/<name>/`

> Source unique du mapping override. Lu par `bootstrap-claude.sh` pour l'install sélectif et par les agents stack pour la cross-ref "je durcis quel rôle".

## Principe

**Règle absolue : on installe soit `roles/`, soit `stacks/<X>/` — jamais les deux fichiers pour un même use case.** La redondance est un anti-pattern (2 experts qui se marchent dessus, ambiguïté d'invocation, tokens gaspillés).

Un fichier stack **hérite** conceptuellement d'un ou plusieurs rôles génériques : il conserve la règle d'or (Sources chargées AVANT, STAY IN SCOPE, format standardisé, cite `file:line`) et **durcit** avec les conventions stack (§14 file size limits, ORM Lucid, multi-tenant Adonis, etc.).

Puisque Claude Code ne supporte pas d'héritage littéral entre fichiers agents, chaque fichier stack est **autoportant** : il contient une section `## Inherits from roles/X` qui résume l'esprit du rôle, puis `## Stack override <name>` avec les durcissements.

## Modes bootstrap

| Mode | Agents installés | Total |
|---|---|---|
| `--stack=none` (defaut CI) | `roles/*` (10) | 10 |
| `--stack=adonisjs` | 6 `roles/` + 7 `stacks/adonisjs/` | 13 |

Le prompt interactif TTY propose ces 2 modes (extensible : futures stacks `laravel`, `nextjs`, `django`).

## Mode `--stack=none` (générique cross-stack)

Installe uniquement `.claude/agents/roles/*.md` (10 fichiers) :

```
analyzer, architect, backend, frontend, mobile,
performance, product-strategist, qa, reviewer, security
```

Aucun expert stack-aware. Recommandé quand la stack projet n'est pas AdonisJS/Node/TS ou quand on veut la palette générique universelle.

## Mode `--stack=adonisjs`

Installe 6 rôles génériques (les rôles cross-stack **non couverts** par un override AdonisJS) + 7 experts stack durcis :

### Rôles conservés (6) — pas d'override AdonisJS

| Role | Pourquoi conservé |
|---|---|
| `analyzer` | Root cause 5 Whys — cross-stack, pas d'équivalent Adonis |
| `frontend` | WCAG 2.1 + design systems — `edge-anti-patterns` (linter narrow) ne couvre PAS le scope UX/a11y |
| `mobile` | iOS HIG + Android Material — hors périmètre backend Adonis |
| `performance` | Core Web Vitals + RAIL cross-stack — pas d'override Adonis |
| `product-strategist` | Strategic gate feature (couche 0) — indépendant de la stack |
| `qa` | Test pyramid + TDD — cross-stack |

### Rôles remplacés par override AdonisJS

Ces rôles **ne sont PAS installés** en mode `adonisjs` — leur override stack prend le relais :

| Role source | Remplacé par | Justification |
|---|---|---|
| `architect` + `backend` | `stacks/adonisjs/back-architect` | Un seul expert back sur AdonisJS §14 (300/400/800L limits), Vine, routes, helpers `_helpers/`. `back-architect` durcit les scopes des deux rôles génériques. |
| `reviewer` | `stacks/adonisjs/code-reviewer` | Review PR-style stack-aware (Adonis conventions + orchestre les autres experts stack en délégation). |
| `security` | `stacks/adonisjs/security-multitenant` | Sécurité Adonis focus : `effectiveUserId`, IDOR via `.where('userId', …).firstOrFail()`, CSRF forms, soft-delete Documents, signed URLs S3. Durcit OWASP générique. |

### Experts stack ajoutés (aucun rôle équivalent)

Ces experts n'ont pas de rôle générique cross-stack équivalent — ils sont **purement stack-specific** :

| Expert stack | Scope |
|---|---|
| `data-access-reviewer` | ORM Lucid (preload vs load), raw SQL, pool, S3 storage, TTL Redis — anti-patterns grepables haiku |
| `edge-anti-patterns` | Templates `.edge` + Alpine directives — 16 patterns P0/P1 grepables haiku (pair avec `roles/frontend` : le rôle fait WCAG/UX, le linter fait patterns Edge) |
| `migration-reviewer` | `database/migrations/*.ts` — §9 DO/DON'T, IF NOT EXISTS, DEFAULT NOT NULL, JSONB, ALTER CONSTRAINT enum |
| `workflow-email` | Domain workflow + email : Mustache `{{contact.firstname}}` Edge vs ICU `{var}` lang JSON, `mail.send()` sync vs `sendLater()` BullMQ, WorkflowBinding enum |

## Diagramme d'héritage

```
                       roles/                         stacks/adonisjs/
                       ──────                         ────────────────
Couche 0 strategic     product-strategist   ─────►    (kept as-is)
Couche 1 architect     architect     ┐
                       backend       ┘   ────────►   back-architect      (durcit + fusionne)
Couche 2 cross-cutting security       ─────────►    security-multitenant (durcit)
                       (no source)   ────ADDS───►   data-access-reviewer
                       (no source)   ────ADDS───►   migration-reviewer
Couche 3 domain        (no source)   ────ADDS───►   workflow-email
Couche 4 linter        frontend      ────PAIR────   edge-anti-patterns   (linter narrow, pas remplacement)
Couche 5 final gate    reviewer       ─────────►   code-reviewer         (durcit + orchestre)

Toujours conservés en mode adonisjs :
  analyzer, mobile, performance, qa                    (cross-stack, aucun override)
```

## Ajouter une stack

Pour ajouter une stack `<X>` (ex : `laravel`, `nextjs`, `django`) :

1. Créer `.claude/agents/stacks/<X>/` avec les experts stack-aware
2. Ajouter une entrée dans cette doc avec le mapping override (quels roles/ sont remplacés, quels sont conservés, quels stacks sont ajoutés)
3. Ajouter le mode `--stack=<X>` dans `bootstrap-claude.sh` (variables `ROLES_KEPT_<X>` et `STACKS_INSTALLED_<X>`)
4. Pour chaque expert stack, ajouter les sections `## Inherits from roles/<Y>` (si override) + `## Stack override <X>` (durcissements)

## Cross-ref

- Bootstrap : [`../../bootstrap-claude.sh`](../../bootstrap-claude.sh)
- Catalogue complet : [`experts.md`](experts.md)
- Setup : [`setup.md`](setup.md)
