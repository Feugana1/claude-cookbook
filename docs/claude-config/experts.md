# Claude Code — catalogue d'experts spécialisés

> Démarche d'automatisation des règles dures du projet via subagents, skills et hooks Claude Code.
> Source unique versionnée. Reproductible cross-poste (voir [`setup.md`](setup.md)).
>
> **Statut** : doc-only — l'implémentation des items est gatée par approbation user, item par item (cf. [§9 Roadmap](#9-roadmap--état-dimplémentation)).

---

## 1. Pourquoi ce système

Une instruction dans [`CLAUDE.md`](../../CLAUDE.md) est **consultative** : suivie ~80 % du temps par la session courante. C'est suffisant pour une convention de nommage, insuffisant pour une règle de sécurité multi-tenant ou une règle NF525.

Une règle **dure** doit être **déterministe** :

| Type de règle | Mécanisme déterministe |
|---|---|
| Pattern grepable interdit (`auth.user.id`, `drive.use()`, `{{{ JSON.stringify`, mid-line `@svg`) | **Hook** `PostToolUse` qui exit 2 |
| Action destructive (`--no-verify`, force push main, `rm -rf /*`, `Write(/.env*)`) | **Permission** `deny` |
| Vérification contextuelle (cohérence NF525, charte design, isolation tenant) | **Subagent expert** dédié, source de vérité dédiée |
| Workflow volontaire (audit UX, pré-PR, scan sécu) | **Skill** invoqué par l'humain |

Le but n'est **pas** de remplacer CLAUDE.md ni d'en abaisser les exigences. C'est de matérialiser les sections P0 sans dépendre de la discipline d'une session donnée.

---

## 2. Architecture à 3 niveaux

```
┌──────────────────────────────────────────────────────────────────┐
│  N3. SKILLS — invocation humaine explicite (/ux-review, /pre-pr) │
├──────────────────────────────────────────────────────────────────┤
│  N2. SUBAGENTS — Claude délègue auto via description-trigger     │
├──────────────────────────────────────────────────────────────────┤
│  N1. HOOKS — PostToolUse Edit/Write : bloque P0, suggère expert  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ↓
┌──────────────────────────────────────────────────────────────────┐
│  Permissions (allow / deny / ask) — settings.json projet         │
└──────────────────────────────────────────────────────────────────┘
```

| Niveau | Mécanisme | Quand se déclenche | Coût |
|---|---|---|---|
| **N1. Hook dispatcher** | Script `PostToolUse` qui match path + grep patterns durs | À chaque `Edit`/`Write`, automatique | ~50ms |
| **N2. Subagent auto-invoqué** | `.claude/agents/*.md` avec `description` précise | Claude détecte que la tâche correspond au scope de l'agent | Contexte isolé |
| **N3. Skill explicite** | `.claude/skills/*/SKILL.md` ou slash command | L'humain tape `/secu`, `/ux-review`, etc. | À la demande |

Le hook (N1) **ne lance pas** les subagents directement (anti-pattern). Il **bloque** les P0 via exit 2 et **suggère** en `stderr` les subagents N2 à invoquer — Claude lit le stderr et décide.

---

## 3. Règle d'or — "L'expert prend le dessus, contextualise, sans complaisance"

C'est le contrat de tout expert (subagent ou skill) du catalogue :

1. **Prend le dessus sur son scope.** Quand un expert est invoqué et que son scope est concerné, sa décision **prime** sur les heuristiques générales de CLAUDE.md ou de la session. Si l'expert NF525 dit "une facture émise ne peut pas être mutée, créer un avoir", la session ne peut pas argumenter qu'un edit serait plus simple.

2. **Charge sa source de vérité dédiée.** Avant tout finding, l'expert lit ses docs sources (ex : `nf525-accounting` lit `docs/accounting.md` + `docs/finances.md`). Aucun expert ne raisonne "de mémoire".

3. **Sans complaisance.** Aucun finding n'est minimisé pour faire passer un PR. Chaque P0 est cité `file:line` avec la règle source. Si un PR viole 5 règles, l'expert en rapporte 5. Un expert qui valide trop facilement perd toute valeur.

4. **Reste contextuel.** L'expert n'audite **que** son scope. Le `nf525-accounting` ne commente pas le CSS d'une page. Le `front-curator` ne discute pas du middleware d'auth. Cela garantit la réutilisabilité et évite les conflits inter-experts.

5. **Cite ses sources.** Chaque finding pointe une règle d'un fichier source (`docs/accounting.md:142`, `CLAUDE.md §13 anti-pattern #4`, `scan-secu.sh:step 22A`). Un finding non sourcé est ignoré.

6. **Format de sortie standardisé.** Chaque expert sort un audit en sections **P0 / P1 / Quick wins / Déjà correct**. Pas de prose libre.

Conséquence opérationnelle : **un expert qui valide une feature pèse plus qu'un avis générique** de session ; un expert qui bloque arrête le merge.

---

## 4. Catalogue

Le catalogue est structuré en **5 couches** pour garantir la symétrie front/back, éviter les drifts de scope et clarifier l'ordre d'invocation :

```
┌──────────────────────────────────────────────────────────────────┐
│  Couche 0 — STRATEGIC GATE (sonnet) : différenciation produit    │
│    product-strategist                                            │
├──────────────────────────────────────────────────────────────────┤
│  Couche 1 — ARCHITECTS (sonnet) : vision + conventions           │
│    front-curator       back-architect                            │
├──────────────────────────────────────────────────────────────────┤
│  Couche 2 — CROSS-CUTTING (sonnet/haiku) : transverses           │
│    security-multitenant                                          │
│    data-access-reviewer (haiku)                                  │
│    migration-reviewer                                            │
├──────────────────────────────────────────────────────────────────┤
│  Couche 3 — DOMAIN (sonnet) : règles métier profondes            │
│    nf525-accounting    shop-marketplace                          │
│    workflow-email      public-experience                         │
│    subscription-quota                                            │
├──────────────────────────────────────────────────────────────────┤
│  Couche 4 — LINTERS (haiku) : fast-pass grep                     │
│    edge-anti-patterns                                            │
├──────────────────────────────────────────────────────────────────┤
│  Couche 5 — FINAL GATE (sonnet) : senior PR-style code review    │
│    code-reviewer                                                 │
└──────────────────────────────────────────────────────────────────┘
```

**Ordre d'invocation type** :
- **Nouvelle feature** : `product-strategist` (couche 0) AVANT tout. Si verdict NO-GO → on ne code pas. Si GO → architects → cross-cutting → domain → linter → **`code-reviewer` (couche 5) AVANT git commit**.
- **Edit existant** : architect (back-architect ou front-curator) → cross-cutting pertinents → domain si touché → linter haiku en parallèle → **`code-reviewer` AVANT git commit**.
- **Bugfix / refactor** : skip couche 0, dispatch couches 1-4 → **`code-reviewer` AVANT git commit**.

La couche 0 ne s'invoque pas sur bugfix/refactor pur (cf §6 "Cas limites" de `product-strategist`).
La couche 5 s'invoque **toujours** avant `git commit` si diff non-trivial (≥ 2 fichiers OU ≥ 50 lignes OU touche app/middleware/migrations/routes).

### 4.1 Subagents projet (`.claude/agents/*.md`)

#### Couche 0 — Strategic gate

| Expert | Model | Source(s) référentiel | Scope (description-trigger) | Tools |
|---|---|---|---|---|
| **`product-strategist`** | sonnet | [`PRODUCT.md`](../../PRODUCT.md) + [`docs/vision.md`](../vision.md) + [`docs/competitive-benchmark/*.md`](../competitive-benchmark/) (13 concurrents trackés) + [`docs/ux-audit-prompt.md`](../ux-audit-prompt.md) §test 60s + [`docs/roadmap.md`](../roadmap.md) | À invoquer AVANT toute nouvelle feature (skill `/feature <nom>` ou auto-trigger sur "ajoute X", "on doit avoir X"). Pose 7 questions canoniques (problème user, benchmark concurrents, différenciation, "the photo leads", test 60s, simplifie/ajoute, anti-références). Verdict strict : GO différentiant / REVOIR / NO-GO | Read, Grep, Glob, WebFetch, WebSearch |

> **product-strategist** est la **gate d'entrée** de toute nouvelle feature. Pas de bugfix ni refactor. Si NO-GO, on ne code pas — c'est la valeur du système. WebFetch/WebSearch lui permettent de rafraîchir les fiches concurrentes (`docs/competitive-benchmark/<concurrent>.md`) quand leur `lastAudit` > 3 mois.

#### Couche 1 — Architects

| Expert | Model | Source(s) référentiel | Scope (description-trigger) | Tools |
|---|---|---|---|---|
| **`front-curator`** | sonnet | [`docs/ux-audit-prompt.md`](../ux-audit-prompt.md) + [`docs/design-system.md`](../design-system.md) + [`PRODUCT.md`](../../PRODUCT.md) + [`docs/vision.md`](../vision.md) | Edit/Write sur `resources/views/**/*.edge`, `resources/css/**`, `resources/js/**` — audit 6 axes UX + charte Digital Curator + density gate >4 sections | Read, Grep, Glob, Bash |
| **`back-architect`** | sonnet | `CLAUDE.md` §3 §8 §14 + [`docs/architecture.md`](../architecture.md) + [`docs/feature-plan-template.md`](../feature-plan-template.md) + [`scripts/check-file-sizes.js`](../../scripts/check-file-sizes.js) + [`docs/anti-patterns.md`](../anti-patterns.md) §Architecture | Edit/Write sur `app/controllers/**`, `app/services/**`, `app/middleware/**`, `app/validators/**`, `start/routes.ts` — conventions AdonisJS, limites 300/400/800L, split patterns, helpers `_helpers/`, naming, validators Vine, routes ordering | Read, Grep, Glob, Bash |

> **back-architect** est le miroir back de `front-curator` : conventions structurelles, naming, file size, split patterns. Il **NE FAIT PAS** sécurité, ORM, business rules — il délègue à la couche 2 ou 3. Garde-fou anti-drift inscrit dans son frontmatter.

#### Couche 2 — Cross-cutting concerns

| Expert | Model | Source(s) référentiel | Scope (description-trigger) | Tools |
|---|---|---|---|---|
| **`security-multitenant`** | sonnet | [`docs/security-multitenant.md`](../security-multitenant.md) + [`docs/anti-patterns.md`](../anti-patterns.md) §Sécurité + [`scan-secu.sh`](../../scan-secu.sh) étapes 22A-F | Edit/Write sur backend touchant l'auth, les queries metier, les middleware, les uploads, les forms — audit `effectiveUserId`, IDOR via `.firstOrFail()`, CSRF, soft-delete, branding loader, swallow helper | Read, Grep, Bash |
| **`data-access-reviewer`** | **haiku** | [`docs/database-neon.md`](../database-neon.md) + `CLAUDE.md` §10/§10b + [`docs/storage-s3.md`](../storage-s3.md) | Reviewer secondaire rapide — questions ORM (preload vs load, await save boucle, raw SQL `${}`, pool min:0) ou storage (`drive.use` direct, TTL Redis vs `expiresIn`) | Read, Grep |
| **`migration-reviewer`** | sonnet | `CLAUDE.md` §9 + §10 + [`docs/anti-patterns.md`](../anti-patterns.md) §ORM | Ajout/edit `database/migrations/**/*.ts` — audit IF NOT EXISTS, DEFAULT pour NOT NULL, JSONB documenté, ALTER CONSTRAINT quand enum TS étendu, `prepare/consume` helpers | Read, Grep, Glob |

#### Couche 3 — Domain experts

| Expert | Model | Source(s) référentiel | Scope (description-trigger) | Tools |
|---|---|---|---|---|
| **`nf525-accounting`** | sonnet | [`docs/accounting.md`](../accounting.md) + [`docs/finances.md`](../finances.md) + [`docs/business-rules.md`](../business-rules.md) §Comptabilité | Edit/Write sur `app/{controllers,services,models}/**{document,invoice,quote,contract,credit,expense}*`, `resources/views/pages/documents/**`, migration touchant `documents`/`invoices` — audit NF525 immutability, numérotation `FOR UPDATE`, soft-delete, devis→facture | Read, Grep, Glob |
| **`shop-marketplace`** | sonnet | [`docs/shop-marketplace.md`](../shop-marketplace.md) + `business-rules.md` §Catalogue | Edit/Write sur `app/{controllers,services}/**shop*` ou `**marketplace*` — audit commission tier, Stripe Connect vs NotchPay Sync, `channels jsonb`, invoice NF525 auto-gen | Read, Grep, Glob |
| **`workflow-email`** | sonnet | [`docs/workflows.md`](../workflows.md) + [`docs/emails.md`](../emails.md) + `CLAUDE.md` §11 row Workflows | Edit/Write sur `app/services/**workflow*`, `app/services/**email*`, `resources/views/emails/**`, `app/models/workflow*` — audit Mustache `{{}}` Edge vs ICU `{}` lang, `mail.send` sync pour lifecycle, `WorkflowBinding` owner_type | Read, Grep, Glob |
| **`public-experience`** | sonnet | [`docs/transfers.md`](../transfers.md) + [`docs/custom-domains.md`](../custom-domains.md) + memory `feedback_subdomain_passthrough` + `scan-secu.sh` 22A/22E | Edit/Write sur `app/controllers/public_*`, `resources/views/pages/{galleries,bookings,transfers,portal}/public/**`, route hors `/admin` — audit `SubdomainMiddleware.globalPassthrough`, `buildPublicShareMeta`, `BrandingService.loadPublicBranding` | Read, Grep, Bash |
| **`subscription-quota`** | sonnet | [`docs/features/subscriptions.md`](../features/subscriptions.md) + [`docs/business-rules.md`](../business-rules.md) §Abonnements + `CLAUDE.md` §11 + `app/services/quota_service.ts` + `app/middleware/quota_middleware.ts` | Edit/Write sur `app/services/**quota*`, `app/services/**subscription*`, `app/middleware/quota*`, `app/middleware/subscription*`, `app/models/plan*`, `app/models/subscription*`, migration touchant plans/subscriptions/quotas — audit architecture 3 couches (Plans → Subscriptions → QuotaService), Redis cache 60s, middleware.quota enforcement sur .store routes, feature flag gate, dunning lifecycle J0/J3/final, trial one-per-user, matrice quotas Starter/Pro/Studio/Agence | Read, Grep, Glob |

#### Couche 4 — Linters

| Expert | Model | Source(s) référentiel | Scope (description-trigger) | Tools |
|---|---|---|---|---|
| **`edge-anti-patterns`** | **haiku** | `CLAUDE.md` §13 + [`docs/anti-patterns.md`](../anti-patterns.md) §Edge/Alpine | Linter rapide sur fichier `.edge` modifié — pass grep contre les 16 patterns P0/P1 du §13 | Read, Grep |

#### Couche 5 — Final gate (senior code review)

| Expert | Model | Source(s) référentiel | Scope (description-trigger) | Tools |
|---|---|---|---|---|
| **`code-reviewer`** | sonnet | Composite : `CLAUDE.md` §13/§14 + `docs/anti-patterns.md` + sources de couche 1-4 chargées dynamiquement selon scope du diff | Use PROACTIVELY IMMEDIATELY BEFORE `git commit` quand le diff est non-trivial (≥ 2 fichiers OU ≥ 50 lignes OU touche `app/`, `resources/views/`, `database/migrations/`, `start/routes.ts`, `app/middleware/`). Lit `git diff --cached`, synthétise findings cross-fichiers en review PR-style senior. Verdict strict **SHIP ✅** / **NEEDS CHANGES 🟡** / **REJECT 🔴**. Délègue aux experts spécialisés couches 1-4 pour deep-dives recommandés. | Read, Grep, Glob, Bash |

> **`code-reviewer` est l'orchestrateur final**. Il ne refait pas le travail des experts spécialisés — il **synthétise cross-fichiers** ce que les hooks et experts file-par-file ne voient pas (cohérence i18n FR+EN, migration + model + validator alignés, doc feature présente, intention claire, régression baseline). Quand un finding nécessite un deep-dive, il **renvoie fermement** vers l'expert dédié. Hook `precommit-check.sh` rappelle son invocation en stderr.

**12 subagents** — 2 haiku (économes, fast-pass), 10 sonnet (audit contextuel + strategic + final review). Les haiku sont parallélisables et invocables en série après n'importe quel autre expert sans peser sur le coût.

### 4.2 Skills (`.claude/skills/*/SKILL.md` + plugin superpowers)

#### 4.2.1 Skills projet custom (4 livrés + 2 backlog)

| Skill | Trigger humain | Action |
|---|---|---|
| **`/feature <nom>`** | AVANT toute nouvelle feature non-triviale | Orchestrateur : invoque `brainstorming` (superpowers) → `product-strategist` (couche 0) → `writing-plans` (superpowers) → dispatch experts couches 1-3 |
| **`/ux-review <page>`** | Avant add-feature config screen, ou "ça paraît dense / chargé" | Charge `ux-audit-prompt.md`, sweep le path. Sortie format P0/P1/Quick wins |
| **`/secu`** | Avant `git push` | Lance `scan-secu.sh`, parse 24 étapes, résume FAIL/WARN, propose fix par FAIL |
| **`/pre-pr`** | Avant créer PR | `npm run lint` → `typecheck` → `node ace build --ignore-ts-errors` → `node scripts/check-file-sizes.js` → résumé |
| **`/nf525-check`** | Avant merge feature compta | Invoque `nf525-accounting`, vérifie parité lang fr/en, vérifie tests compta (backlog R09c) |
| **`/wf-scaffold <action\|trigger>`** | Nouveau trigger/action workflow | Génère stub TS + enum + binding + variables `buildVarCtx` + check ICU/Mustache (backlog R09d) |

#### 4.2.2 Skills superpowers (plugin, 14 disponibles)

Plugin `superpowers@claude-plugins-official` v5.1.0 (installé 2026-05-31).

| Catégorie | Skill | Quand l'invoquer (cf [`superpowers-integration.md`](superpowers-integration.md) §4) |
|---|---|---|
| Meta | `using-superpowers` | Convention plugin — orchestre invocation des autres skills |
| Meta | `writing-skills` | Créer ou refondre un skill custom |
| Amont | `brainstorming` | Refactor / changement structurel non-feature (sinon `/feature` projet) |
| Amont | `writing-plans` | Après brainstorming, avant code |
| Amont | `executing-plans` | Exécuter un plan inline avec checkpoints |
| Amont | `subagent-driven-development` | Exécuter un plan via subagents fresh par tâche |
| Pendant | `test-driven-development` | Zone critique (NF525, security, paiement) |
| Pendant | `systematic-debugging` | Bug non trivial |
| Pendant | `using-git-worktrees` | Isolation d'un workspace |
| Pendant | `dispatching-parallel-agents` | 2+ tâches indépendantes en // |
| Aval | `verification-before-completion` | Avant tout claim "terminé" (gap pur) |
| Aval | `requesting-code-review` | (remplacé par `code-reviewer` subagent projet) |
| Aval | `receiving-code-review` | Recevoir feedback PR |
| Aval | `finishing-a-development-branch` | Décider merge vs PR vs cleanup |

> **Règle d'or routage** : skill projet PRIME sur équivalent superpowers générique. Voir [`superpowers-integration.md`](superpowers-integration.md) §3 et §4.

### 4.3 Permissions (`.claude/settings.json` projet — partagé)

| Type | Patterns | Justification |
|---|---|---|
| `deny` | `Bash(git commit *--no-verify*)`, `Bash(git push *--no-verify*)` | CLAUDE.md §"Never skip hooks" |
| `deny` | `Bash(git push --force* main*)`, `Bash(git push --force* develop*)` | Pas de force push sur branches protégées |
| `deny` | `Bash(rm -rf /*)`, `Bash(rm -rf ~*)` | Action destructive racine |
| `deny` | `Write(./.env)`, `Write(./.env.local)`, `Write(./.env.keys)`, `Edit(./.env)`, `Edit(./.env.local)`, `Edit(./.env.keys)` | Pas d'écriture sur secrets |
| `ask` | `Bash(npm install *)`, `Bash(npm uninstall *)`, `Bash(npm update *)` | Modifie `package-lock.json` partagé |
| `ask` | `Bash(node ace migration:rollback*)` | Action irréversible DB |
| `allow` | Patterns équipe stables (lint, typecheck, build, scan, test, git read-only…) | Évite friction sur opérations safe |

Les permissions locales spécifiques (one-shot perl/sed/awk) restent dans `.claude/settings.local.json` gitignore.

### 4.4 Hook dispatcher (`.claude/hooks/dispatch-expert.sh`)

```bash
#!/usr/bin/env bash
# PostToolUse hook — read JSON from stdin via Claude Code, identify
# domain by path, grep P0 patterns, suggest expert in stderr.
# Exit 2 = block tool. Exit 0 = pass.

set -euo pipefail
input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name')
[ "$tool" = "Edit" ] || [ "$tool" = "Write" ] || exit 0
file=$(echo "$input" | jq -r '.tool_input.file_path')
[ -f "$file" ] || exit 0

# ----- Front / Edge -----
case "$file" in
  *.edge|resources/css/*|resources/js/*)
    # P0 grep
    if grep -nE '\{\{\{ JSON\.stringify|@(click|input|blur|change)[^"]*=|^[^[:space:]]+.*@svg\(' "$file" >/dev/null 2>&1; then
      echo "BLOCKED [edge-P0]: anti-pattern in $file. Invoke 'edge-anti-patterns' subagent." >&2
      exit 2
    fi
    echo "Hint: invoke 'front-curator' subagent to audit $file." >&2
    exit 0
    ;;
esac

# ----- Backend TS -----
case "$file" in
  app/controllers/*|app/services/*|app/middleware/*|app/validators/*|start/routes.ts)
    # P0 grep (security)
    if grep -nE 'auth\.user\.id|drive\.use\(|\.catch\(\(\) => \{\}\)' "$file" >/dev/null 2>&1; then
      echo "BLOCKED [security-P0]: anti-pattern in $file. Invoke 'security-multitenant' subagent." >&2
      exit 2
    fi
    # Layered hints : architect (always) → cross-cutting (security) → domain (if matched)
    echo "Hint: invoke 'back-architect' subagent (conventions + structure)." >&2
    echo "Hint: invoke 'security-multitenant' subagent (cross-cutting security)." >&2
    case "$file" in
      *document*|*invoice*|*quote*|*contract*|*credit*|*expense*)
        echo "Hint: invoke 'nf525-accounting' subagent (domain)." >&2 ;;
      *workflow*|*email*|*mail*)
        echo "Hint: invoke 'workflow-email' subagent (domain)." >&2 ;;
      *shop*|*marketplace*)
        echo "Hint: invoke 'shop-marketplace' subagent (domain)." >&2 ;;
      *public_*)
        echo "Hint: invoke 'public-experience' subagent (domain)." >&2 ;;
    esac
    ;;
esac

# ----- Migrations -----
case "$file" in
  database/migrations/*)
    echo "Hint: invoke 'migration-reviewer' subagent." >&2
    ;;
esac

exit 0
```

Le hook est versionné dans `.claude/hooks/` (après refactor `.gitignore` cf [setup.md](setup.md)).

---

## 5. Mapping path → expert (référence rapide)

L'ordre est : **architect → cross-cutting → domain → linter**. Le hook dispatcher suit cet ordre.

| Path glob | Architect | Cross-cutting | Domain (si applicable) | Linter |
|---|---|---|---|---|
| `resources/views/**/*.edge` | `front-curator` | — | — | `edge-anti-patterns` |
| `resources/css/**`, `resources/js/**` | `front-curator` | — | — | — |
| `app/controllers/**/*.ts` | `back-architect` | `security-multitenant` | selon sous-domaine (cf hook) | — |
| `app/services/**/*.ts` | `back-architect` | `security-multitenant`, `data-access-reviewer` | selon sous-domaine | — |
| `app/middleware/**/*.ts` | `back-architect` | `security-multitenant` | — | — |
| `app/validators/**/*.ts` | `back-architect` | `security-multitenant` | — | — |
| `app/models/**/*.ts` | `back-architect` | `data-access-reviewer` | `nf525-accounting` si table compta | — |
| `database/migrations/**/*.ts` | — | `migration-reviewer` | `nf525-accounting` si table compta | — |
| `app/{controllers,services,models}/**{document,invoice,quote,contract,credit,expense}*` | `back-architect` | `security-multitenant` | `nf525-accounting` | — |
| `app/{controllers,services}/**shop*\|**marketplace*` | `back-architect` | `security-multitenant` | `shop-marketplace` (+`nf525-accounting` invoice auto-gen) | — |
| `app/services/**quota*\|**subscription*`, `app/middleware/quota*\|subscription*`, `app/models/plan*\|subscription*` | `back-architect` | `security-multitenant` | `subscription-quota` | — |
| `app/services/**workflow*\|**email*\|**mail*`, `resources/views/emails/**` | `back-architect` | — | `workflow-email` | — |
| `app/controllers/public_*`, `resources/views/pages/*/public/**` | `back-architect` ou `front-curator` (selon front/back) | `security-multitenant` | `public-experience` | `edge-anti-patterns` (si .edge) |
| `start/routes.ts` | `back-architect` | `security-multitenant` | `public-experience` si nouvelle route hors `/admin` | — |

---

## 6. Sources de vérité — détail par expert

Chaque expert charge **uniquement** ces fichiers comme source canonique. Aucun raisonnement "de mémoire".

### `front-curator`
- [`docs/ux-audit-prompt.md`](../ux-audit-prompt.md) — 6 axes (User-first / PLG / Design System / Pas de redondance / Premium visuel / Restraint cognitif), critères P0/P1, format sortie obligatoire, test 60s
- [`docs/design-system.md`](../design-system.md) — Digital Curator (956L), tokens (15 cat. @theme), interdits critiques (table No-Line / z-scale / gradient brand / font-display), composants ref, checklist §17
- [`PRODUCT.md`](../../PRODUCT.md) — "the photo leads", anti-references (SaaS générique, tableur, glassmorphism), 5 design principles
- [`docs/vision.md`](../vision.md) — modules narratifs, expérience sensorielle, écarts identifiés (CRM Kanban, fidélisation, pont galerie→portfolio)
- `CLAUDE.md` §7 (charte rappels) + §17.6 (UI density gate >4 sections)

### `back-architect`
- `CLAUDE.md` §3 (nommage tables/models/controllers/services/validators/routes/partials/i18n)
- `CLAUDE.md` §8 (workflow nouvelle feature 6-step + checklist)
- `CLAUDE.md` §14 (limites 300/400/800L + 1 controller=1 domaine + service=1 responsabilité + helpers `_helpers/` dès 2+ callers + raw SQL paramétré + dark Tailwind + Alpine modules Vite)
- [`docs/architecture.md`](../architecture.md) — architecture globale, couches, conventions transverses
- [`docs/feature-plan-template.md`](../feature-plan-template.md) — template obligatoire pour toute feature
- [`scripts/check-file-sizes.js`](../../scripts/check-file-sizes.js) — ratchet baseline, mécanique fail
- [`docs/anti-patterns.md`](../anti-patterns.md) §Architecture — patterns process (controllers >300, services non splittés, duplication helpers)

**STAY IN SCOPE** — back-architect refuse explicitement de commenter : sécurité, IDOR, ORM, business rules, charte UI, règles compta. Il délègue.

### `security-multitenant`
- [`docs/security-multitenant.md`](../security-multitenant.md) — OWASP, ANSSI, middleware (auth/team/editor/admin/subscription/quota/antivirus), `effectiveUserId`, IDOR via `.firstOrFail()`, CSP, webhooks, CSRF
- [`docs/anti-patterns.md`](../anti-patterns.md) §Sécurité (P0 effectiveUserId, drive.use, soft-delete)
- [`scan-secu.sh`](../../scan-secu.sh) étapes **22A** (OG meta `buildPublicShareMeta`), **22B** (drive.use), **22C** (auth scope), **22D** (Document soft-delete), **22E** (BrandingService.loadPublicBranding), **22F** (swallow helper)
- `CLAUDE.md` §11 + §12 + §13

### `nf525-accounting`
- [`docs/accounting.md`](../accounting.md) — 970L : workflow statuts, PDF Puppeteer, NF525 (numérotation `FOR UPDATE`, immutability), conversion devis→facture, signature électronique
- [`docs/finances.md`](../finances.md) — 284L : dépenses = `Document type=INVOICE` + `Invoice invoiceType=EXPENSE`, fournisseur = `Contact isSupplier=true`, dépenses récurrentes
- [`docs/business-rules.md`](../business-rules.md) §Comptabilité — soft delete, immutabilité, recall DRAFT
- Memory `feedback_doc_code_on_status_transition` — DRAFT→PENDING/SENT doit générer code + emittedAt

### `shop-marketplace`
- [`docs/shop-marketplace.md`](../shop-marketplace.md) — 2394L : commission 5/3/2/1 % par tier (`MarketplaceCommissionService`), Stripe Connect EUR + NotchPay Sync XAF/XOF, lifecycle `shop_order` PENDING→PAID→FULFILLED→REFUNDED, photo-templates overlay PNG, Stripe Tax inclusive
- [`docs/business-rules.md`](../business-rules.md) §Catalogue — 4 canaux (INVOICE/GALLERY/BOOKING/STANDALONE) via `channels jsonb`, smart defaults, `service_type_id` FK
- Cross-ref `nf525-accounting` quand `shop_order_invoicing_service` est touché

### `workflow-email`
- [`docs/workflows.md`](../workflows.md) — 940L : 10 triggers + 10 actions, `WorkflowBinding` owner_type, variable interpolation `{{contact.firstname}}` via `WorkflowService.buildVarCtx()`, anti-screenshot galerie, feature gate `hasWorkflows`
- [`docs/emails.md`](../emails.md) — 707L : services par domaine, `mail.send` sync vs `mail.sendLater` BullMQ, templates Edge `@if(locale === 'en')` (pas `t()`), `@component('emails/_layout')` + `@end`
- `CLAUDE.md` §11 row Workflows + §13 anti-pattern Mustache lang JSON

### `public-experience`
- [`docs/transfers.md`](../transfers.md) — sous-domaine `t.picstudio.fr`, jobs expiration/reminder
- [`docs/custom-domains.md`](../custom-domains.md) — DNS, SSL
- Memory `feedback_subdomain_passthrough` — toute route publique top-level → `SubdomainMiddleware.globalPassthrough`
- `scan-secu.sh` 22A (OG via `buildPublicShareMeta`) + 22E (branding via `BrandingService.loadPublicBranding`)

### `migration-reviewer`
- `CLAUDE.md` §9 (DO/DON'T migration) + §10 (perf DB)
- [`docs/anti-patterns.md`](../anti-patterns.md) §ORM — `.enum()` étendu sans `ALTER CONSTRAINT`, JSONB sans `prepare/consume`
- [`docs/database-neon.md`](../database-neon.md) — pool, autosuspend, `IF NOT EXISTS`

### `data-access-reviewer` (secondaire, haiku)
- [`docs/database-neon.md`](../database-neon.md) — pool config, `.preload()` jamais `.load()`, `.whereNull('deletedAt')`, raw SQL paramétré
- `CLAUDE.md` §10 + §10b — TTL Redis dérivé de `expiresIn - 5min`
- [`docs/storage-s3.md`](../storage-s3.md) — `StorageService.upload/.delete/.getStream`, signed URLs

### `subscription-quota`
- [`docs/features/subscriptions.md`](../features/subscriptions.md) — 4 tiers (Starter/Pro/Studio/Agence), 11 quotas numériques, 12 feature flags, tarification multi-devises EUR/XAF, dunning J0/J3/final, trial one-per-user, grant MANUAL
- [`docs/business-rules.md`](../business-rules.md) §Abonnements — Grant MANUAL auto-annulation, matrice quotas valeurs exactes (contacts 15/200/500/-1, documents 5/150/-1/-1, galeries 2/10/-1/-1, services 3/10/-1/-1, questionnaires 3/10/-1/-1), commission marketplace 5% Starter
- `CLAUDE.md` §11 rows Abonnements + Commission marketplace + §13 anti-pattern `sendLater` sur lifecycle critique
- `app/services/quota_service.ts` — Redis cache 60s, `checkQuota()`, `UpgradePlan` suggestion, `invalidateCache()`
- `app/middleware/quota_middleware.ts` — mode `resource` (quota numérique) vs mode `feature` (feature flag)

### `edge-anti-patterns` (linter rapide, haiku)
- `CLAUDE.md` §13 — 16 patterns P0/P1
- [`docs/anti-patterns.md`](../anti-patterns.md) §Edge/Alpine

---

## 7. Anti-complaisance — ce qui distingue un expert d'un avis générique

Un expert doit **éviter 4 dérives** identifiées :

| Dérive | Manifestation | Garde-fou dans frontmatter |
|---|---|---|
| **Validation paresseuse** | "Globalement ça a l'air OK" sans grep ni cite | Imposer format sortie strict P0/P1/Quick wins/Déjà correct, chaque ligne avec `file:line` |
| **Drift de scope** | L'expert UI commente le SQL ; l'expert NF525 critique le CSS | Description-trigger précise + instruction explicite "STAY IN SCOPE — refuse to comment outside [paths listed]" |
| **Mémorisation au lieu de lecture** | L'expert répond sans avoir Read la source de vérité | Premier output obligatoire = ligne "Sources chargées : [liste fichiers Read]". Si manquant, audit invalide |
| **Conciliation diplomatique** | "C'est P0 mais on peut le faire après" | Pas de soft-P0. Soit c'est P0 (bloque), soit c'est P1 (avant merge), soit Quick win. Pas de catégorie "à voir" |

Le prompt système de chaque agent (frontmatter `description` + corps du `.md`) doit explicitement :
- Lister les fichiers sources à Read AVANT toute analyse
- Imposer le format sortie standardisé
- Interdire les commentaires hors scope
- Rappeler que valider par complaisance détruit la valeur du système

---

## 8. Convention de versionnement

Tous les artefacts de cette démarche **doivent être versionnés** :

| Artefact | Path | Versionné ? |
|---|---|---|
| Agents | `.claude/agents/*.md` | OUI (whitelist `.gitignore`) |
| Skills projet | `.claude/skills/*/SKILL.md` + `references/` + `scripts/` | OUI |
| Commands | `.claude/commands/*.md` | OUI |
| Settings partagés | `.claude/settings.json` | OUI |
| Hooks scripts | `.claude/hooks/*.sh` | OUI |
| Settings perso | `.claude/settings.local.json` | NON (gitignore) |
| Tmp / cache | `.claude/{tmp,cache,statsig,sessions}/` | NON |

`.gitignore` cible (cf R01 dans la roadmap) :

```gitignore
# .claude/ — whitelist du versionnable
.claude/*
!.claude/agents/
!.claude/skills/
!.claude/commands/
!.claude/hooks/
!.claude/settings.json
```

---

## 9. Roadmap & état d'implémentation

**Tous les items ci-dessous sont gatés par approbation user — aucun ne sera implémenté sans `go` explicite.**

| ID | Prio | Statut | Description |
|---|---|---|---|
| **R01** | P0 | **FAIT 2026-05-30** | Refactor `.gitignore` : whitelist `.claude/{agents,skills,commands,hooks,settings.json}` |
| **R02** | P0 | **FAIT 2026-05-30** | Créer `.claude/settings.json` projet (hooks + permissions équipe) |
| **R03** | P0 | **FAIT 2026-05-30** | Ajouter `permissions.deny` (no-verify, force push, rm -rf, .env writes) |
| **R04a** | P0 | **FAIT 2026-05-30** | Hook dispatcher `.claude/hooks/dispatch-expert.sh` (testé conditions réelles) |
| **R04b** | P0 | **FAIT 2026-05-30** | Subagent `edge-anti-patterns` (haiku) |
| **R04c** | P0 | **FAIT 2026-05-30** | Subagent `security-multitenant` (sonnet) |
| **R05** | P0 | **FAIT 2026-05-30** | Hook PreToolUse `Bash(git commit*)` → typecheck + check:sizes |
| **R06a** | P1 | **FAIT 2026-05-30** | Subagent `front-curator` (sonnet) |
| **R06b** | P1 | **FAIT 2026-05-30** | Subagent `back-architect` (sonnet) — mirror back de front-curator |
| **R07a** | P1 | **FAIT 2026-05-30** | Subagent `nf525-accounting` (sonnet) |
| **R07b** | P1 | **FAIT 2026-05-30** | Subagent `migration-reviewer` (sonnet) |
| **R07c** | P1 | **FAIT 2026-05-30** | Subagent `workflow-email` (sonnet) |
| **R07d** | P1 | **FAIT 2026-05-30** | Subagent `shop-marketplace` (sonnet) |
| **R07e** | P1 | **FAIT 2026-05-30** | Subagent `public-experience` (sonnet) |
| **R07f** | P2 | **FAIT 2026-05-30** | Subagent `data-access-reviewer` (haiku) |
| **R08** | P1 | **FAIT 2026-05-30** | Skill `/ux-review` versionné (existait local, sorti du gitignore via R01) |
| **R09a** | P1 | **FAIT 2026-05-30** | Skill `/secu` (wrapper scan-secu.sh + résumé) |
| **R09b** | P1 | **FAIT 2026-05-30** | Skill `/pre-pr` (séquence pré-PR) |
| **R09c** | P2 | À FAIRE | Skill `/nf525-check` |
| **R09d** | P2 | À FAIRE | Skill `/wf-scaffold` |
| **R10** | P1 | À FAIRE | `~/.claude/CLAUDE.md` (préférences user cross-projet) — hors versionnement projet |
| **R11** | P1 | À FAIRE | Nettoyer `settings.local.json` (165 → ~25 entrées) |
| **R08b** | P2 | À FAIRE | Skill `/ux-review` : ajouter `references/` pour progressive disclosure (sortir 50% du SKILL.md vers refs) |
| **R12** | P0 | **FAIT 2026-05-30** | Subagent `product-strategist` (couche 0 strategic gate) — différenciation produit AVANT toute feature |
| **R13** | P0 | **FAIT 2026-05-30** | Référentiel `docs/competitive-benchmark/` : README + template + 13 fichiers concurrents (Pixieset, Pic-Time, Honeybook, Tave, Studio Ninja, 17hats, Iris Works, ShootProof, Sprout Studio, Cloudspot, Unscripted, Picflow, Pelli) — 5 enrichis via WebFetch, 8 squelette à enrichir |
| **R14** | P0 | **FAIT 2026-05-30** | Skill `/feature <nom>` (orchestrateur démarche complète — strategic gate puis dispatch experts) |
| **R15** | P0 | **FAIT 2026-05-30** | Update `CLAUDE.md §8` : step 0 strategic gate ajouté en tête du workflow nouvelle feature |
| **R16** | P0 | **FAIT 2026-05-30** | Subagent `code-reviewer` (couche 5 final gate) — senior PR-style review du `git diff --cached`. Orchestre `scan-secu.sh` (24 étapes) + hooks + experts spécialisés — ne duplique pas leur travail. Verdict strict SHIP/NEEDS CHANGES/REJECT |
| **R17** | P0 | **FAIT 2026-05-30** | Update `precommit-check.sh` : suggère en stderr l'invocation `code-reviewer` si diff non-trivial (≥ 2 fichiers OU ≥ 50 lignes OU touche app/middleware/migrations/routes) |
| **R18** | P1 | **FAIT 2026-05-30** | Subagent `subscription-quota` (couche 3 domain) — audit architecture 3 couches pricing (Plans → Subscriptions → QuotaService), enforcement middleware.quota, dunning lifecycle, trial one-per-user, matrice quotas Starter/Pro/Studio/Agence, gaps d'enforcement tracker |
| **R19** | P0 | **FAIT 2026-05-31** | Installation plugin `superpowers@claude-plugins-official` v5.1.0 (14 skills) |
| **R20** | P0 | **FAIT 2026-05-31** | Doc `docs/claude-config/superpowers-integration.md` — règle d'or routage + matrice |
| **R21** | P0 | **FAIT 2026-05-31** | Refonte `.claude/skills/feature/SKILL.md` au format superpowers (HARD-GATE + dot + Red Flags + 3 refs) |
| **R22** | P0 | **FAIT 2026-05-31** | Refonte `.claude/skills/ux-review/SKILL.md` au format superpowers + 3 refs |
| **R23** | P0 | **FAIT 2026-05-31** | Refonte `.claude/skills/secu/SKILL.md` au format superpowers + 1 ref |
| **R24** | P0 | **FAIT 2026-05-31** | Refonte `.claude/skills/pre-pr/SKILL.md` au format superpowers + 1 ref |
| **R25** | P0 | **FAIT 2026-05-31** | CLAUDE.md §17.7 — section "Skills superpowers" + pointers §17.1/3/5 |
| **R26** | P0 | **FAIT 2026-05-31** | Anti-pattern `docs/anti-patterns.md` "Double-discipline gratuite" |
| **R27** | P0 | **FAIT 2026-05-31** | Memory `feedback_superpowers_routing.md` (règle d'or persistante) |
| **R28** | P1 | À FAIRE (Phase B) | Enforcement hard-gate `precommit-check.sh` (bloque si gates violées) |
| **R29** | P1 | À FAIRE (Phase B) | Hook `dispatch-expert.sh` étendu — hints skills superpowers selon contexte |
| **R30** | P2 | À FAIRE (Phase B) | Refonte format des 12 subagents — dot diagram + Red Flags |

**Ordre de séquencement recommandé** : R01 → R02 → R03 → R04a + R04b + R04c (bloc P0) en un shot, puis itération couche métier par couche métier (R06a + R06b → R07a → R07b → …) avec test réel entre chaque.

---

## 10. Reproductibilité cross-poste

Voir [`setup.md`](setup.md) — procédure step-by-step pour un nouveau poste.

Principe : tout ce qui est dans `.claude/` versionné (post-R01) suffit à reproduire l'environnement. Le seul élément manuel : `~/.claude/settings.json` user (préférences) + `claude login` pour `.credentials.json`.

---

## 11. Maintenance

- **Quand ajouter un expert** : nouveau domaine métier (>1 doc dédié + >3 anti-patterns spécifiques), ou douleur récurrente sur un type de fichier (>3 corrections user en 1 mois).
- **Quand mettre à jour un expert** : modification structurelle de son scope (nouveau sous-domaine, nouveau pattern P0), ou évolution de sa source de vérité (doc référencée enrichie).
- **Quand retirer un expert** : son scope a été absorbé par un autre, ou son taux d'invocation est nul depuis >2 mois.
- **Audit trimestriel** : passer en revue (a) taux d'invocation réel, (b) faux positifs hook, (c) findings ignorés par PR (= règle à renforcer ou à assouplir).

Toute évolution = entrée datée dans [`docs/dev-changelog.md`](../dev-changelog.md) + mise à jour ici.
