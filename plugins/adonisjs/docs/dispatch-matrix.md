# `/feature` — Matrice de dispatch des experts

Référence chargée par `SKILL.md` step 7. Décrit quel expert invoquer selon le scope de la feature.

Note : les experts marqués **projet-specific** sont OPTIONNELS. Le pack n'installe que les experts génériques de la stack ; un projet peut ajouter les siens dans `.claude/agents/` (nf525-accounting, shop-marketplace, public-experience, subscription-quota, front-curator, etc.). Le skill vérifie `.claude/agents/<name>.md` et n'invoque que ceux qui existent.

## Architects (toujours invoqués)

| Si la feature touche... | Invoquer |
|---|---|
| UI Edge/CSS/JS (`resources/views/**`, `resources/css/**`, `resources/js/**`) | `<front-architect>` **projet-specific** si présent |
| Backend TS (`app/controllers/**`, `app/services/**`, `app/middleware/**`) | `back-architect` (couche 1 cookbook) |

## Cross-cutting (toujours invoqués si backend touché)

| Si la feature touche... | Invoquer |
|---|---|
| Backend metier (auth, queries, uploads, forms) | `security-multitenant` (couche 2 cookbook) |
| Lucid queries, raw SQL, storage S3, Redis cache | `data-access-reviewer` (couche 2 cookbook, haiku) |
| `database/migrations/**/*.ts` | `migration-reviewer` (couche 2 cookbook) |

## Domain (projet-specific — optionnels)

| Si la feature touche... | Invoquer si présent dans .claude/agents/ |
|---|---|
| Documents/invoices/quotes/contracts/credit-notes/expenses (compta) | `nf525-accounting` (ou équivalent) |
| Shop/marketplace/campaign | `shop-marketplace` (ou équivalent) |
| Workflows/emails/mail templates | expert domain du projet — modèle : `docs/templates/example-domain-agent.md` |
| Routes publiques hors admin, transferts, custom domains | `public-experience` (ou équivalent) |
| Subscriptions/quotas/plans/dunning/feature flags | `subscription-quota` (ou équivalent) |

## Linter (parallèle, économe)

| Si la feature touche... | Invoquer |
|---|---|
| Fichier `.edge` (templates) | `edge-anti-patterns` (couche 4 cookbook, haiku, parallèle après autres experts) |

## Final gate (avant `git commit`)

| Toujours, avant commit non-trivial | Invoquer |
|---|---|
| ≥ 2 fichiers OU ≥ 50 lignes OU touche `app/middleware/migrations/routes` | `code-reviewer` (couche 5 cookbook, final) |

## Cas combinés fréquents

### Feature backend metier (ex: nouveau workflow trigger)
1. `back-architect` (structure)
2. `security-multitenant` (effectiveUserId, IDOR)
3. `data-access-reviewer` (preload, soft-delete)
4. expert domain projet-specific (si concerné)
5. `code-reviewer` (avant commit)

### Feature UI nouvelle page admin
1. `<front-architect>` projet-specific si présent (charte + density gate)
2. `back-architect` (controller correspondant)
3. `security-multitenant` (route protégée)
4. `edge-anti-patterns` (linter `.edge`)
5. `code-reviewer` (avant commit)

### Feature surface publique (galerie partagée, booking public, etc.)
1. `<front-architect>` projet-specific si présent (UI publique)
2. `back-architect` (controller public_)
3. `security-multitenant` (CSRF, signed URLs)
4. `<public-experience>` projet-specific si présent (subdomain passthrough, OG meta, branding loader)
5. `edge-anti-patterns`
6. `code-reviewer`

### Feature domaine sensible (ex: compta, paiement, audit)
1. `back-architect`
2. `security-multitenant`
3. `data-access-reviewer`
4. `<domain-expert>` projet-specific si présent (immutabilité, règles métier)
5. `migration-reviewer` (si migration)
6. `code-reviewer`

## Convention d'invocation

- Architects + cross-cutting : peuvent tourner **en parallèle** (3-4 subagents en //)
- Domain : un seul à la fois (séquentiel — le domaine impose ordre)
- Linter haiku (`edge-anti-patterns`, `data-access-reviewer`) : économe, parallélisable
- `code-reviewer` : toujours **en dernier**, après que tous les findings ont été appliqués
