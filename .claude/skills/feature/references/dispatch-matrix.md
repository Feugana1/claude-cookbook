# `/feature` — Matrice de dispatch des experts

Référence chargée par `SKILL.md` step 7. Décrit quel expert invoquer selon le scope de la feature.

## Architects (toujours invoqués)

| Si la feature touche... | Invoquer |
|---|---|
| UI Edge/CSS/JS (`resources/views/**`, `resources/css/**`, `resources/js/**`) | `front-curator` |
| Backend TS (`app/controllers/**`, `app/services/**`, `app/middleware/**`) | `back-architect` |

## Cross-cutting (toujours invoqués si backend touché)

| Si la feature touche... | Invoquer |
|---|---|
| Backend metier (auth, queries, uploads, forms) | `security-multitenant` |
| Lucid queries, raw SQL, storage S3, Redis cache | `data-access-reviewer` |
| `database/migrations/**/*.ts` | `migration-reviewer` |

## Domain (selon sous-scope)

| Si la feature touche... | Invoquer |
|---|---|
| Documents/invoices/quotes/contracts/credit-notes/expenses | `nf525-accounting` |
| Shop/marketplace/campaign | `shop-marketplace` |
| Workflows/emails/mail templates | `workflow-email` |
| Routes publiques hors `/admin`, transferts, custom domains | `public-experience` |
| Subscriptions/quotas/plans/dunning/feature flags | `subscription-quota` |

## Linter (parallèle, économe)

| Si la feature touche... | Invoquer |
|---|---|
| Fichier `.edge` (templates) | `edge-anti-patterns` (haiku, parallèle après autres experts) |

## Final gate (avant `git commit`)

| Toujours, avant commit non-trivial | Invoquer |
|---|---|
| ≥ 2 fichiers OU ≥ 50 lignes OU touche `app/middleware/migrations/routes` | `code-reviewer` (couche 5 final) |

## Cas combinés fréquents

### Feature backend metier (ex: nouveau workflow trigger)
1. `back-architect` (structure)
2. `security-multitenant` (effectiveUserId, IDOR)
3. `data-access-reviewer` (preload, soft-delete)
4. `workflow-email` (domain)
5. `code-reviewer` (avant commit)

### Feature UI nouvelle page admin
1. `front-curator` (charte Digital Curator + density gate)
2. `back-architect` (controller correspondant)
3. `security-multitenant` (route protégée)
4. `edge-anti-patterns` (linter `.edge`)
5. `code-reviewer` (avant commit)

### Feature surface publique (galerie partagée, booking public)
1. `front-curator` (UI publique)
2. `back-architect` (controller public_)
3. `security-multitenant` (CSRF, signed URLs)
4. `public-experience` (subdomain passthrough, OG meta, branding loader)
5. `edge-anti-patterns`
6. `code-reviewer`

### Feature compta (nouveau type document, calcul TVA)
1. `back-architect`
2. `security-multitenant`
3. `data-access-reviewer`
4. `nf525-accounting` (immutabilité, soft-delete, numérotation `FOR UPDATE`)
5. `migration-reviewer` (si migration)
6. `code-reviewer`

## Convention d'invocation

- Architects + cross-cutting : peuvent tourner **en parallèle** (3-4 subagents en // — voir `superpowers:dispatching-parallel-agents`)
- Domain : un seul à la fois (séquentiel)
- Linter haiku (`edge-anti-patterns`, `data-access-reviewer`) : économe, parallélisable
- `code-reviewer` : toujours **en dernier**, après que tous les findings ont été appliqués
