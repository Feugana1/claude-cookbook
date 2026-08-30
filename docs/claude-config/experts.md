# Claude Code — catalogue d'experts spécialisés

> Démarche d'automatisation des règles dures du projet via subagents, skills et hooks Claude Code.
> Doc maître du cookbook. Reproductible cross-poste (voir [`setup.md`](setup.md)).

---

## 1. Pourquoi ce système

Une instruction dans `CLAUDE.md` est **consultative** : suivie ~80 % du temps par la session courante. C'est suffisant pour une convention de nommage, insuffisant pour une règle de sécurité multi-tenant ou une règle métier critique.

Une règle **dure** doit être **déterministe** :

| Type de règle | Mécanisme déterministe |
|---|---|
| Pattern grepable interdit (`auth.user.id`, `drive.use()`, `{{{ JSON.stringify`, mid-line `@svg`) | **Hook** `PostToolUse` qui exit 2 |
| Action destructive (`--no-verify`, force push main, `rm -rf /*`, `Write(/.env*)`) | **Permission** `deny` |
| Vérification contextuelle (cohérence NF525, charte design, isolation tenant) | **Subagent expert** dédié, source de vérité dédiée |
| Workflow volontaire (audit UX, pré-PR, scan sécu) | **Skill** invoqué par l'humain |

Le but n'est **pas** de remplacer `CLAUDE.md` ni d'en abaisser les exigences. C'est de matérialiser les sections P0 sans dépendre de la discipline d'une session donnée.

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
│  Permissions (allow / deny / ask) — settings.json cookbook       │
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

1. **Prend le dessus sur son scope.** Quand un expert est invoqué et que son scope est concerné, sa décision **prime** sur les heuristiques générales de `CLAUDE.md` ou de la session.

2. **Charge sa source de vérité dédiée.** Avant tout finding, l'expert lit ses docs sources (ex : un expert compta lit `docs/accounting.md` du projet). Aucun expert ne raisonne "de mémoire".

3. **Sans complaisance.** Aucun finding n'est minimisé pour faire passer un PR. Chaque P0 est cité `file:line` avec la règle source. Si un PR viole 5 règles, l'expert en rapporte 5. Un expert qui valide trop facilement perd toute valeur.

4. **Reste contextuel.** L'expert n'audite **que** son scope. Un expert compta ne commente pas le CSS d'une page. Un expert front ne discute pas du middleware d'auth. Cela garantit la réutilisabilité et évite les conflits inter-experts.

5. **Cite ses sources.** Chaque finding pointe une règle d'un fichier source (`docs/accounting.md:142`, `CLAUDE.md §13 anti-pattern #4`, `scan-secu.sh:step 22A`). Un finding non sourcé est ignoré.

6. **Format de sortie standardisé.** Chaque expert sort un audit en sections **P0 / P1 / Quick wins / Déjà correct**. Pas de prose libre.

Conséquence opérationnelle : **un expert qui valide une feature pèse plus qu'un avis générique** de session ; un expert qui bloque arrête le merge.

---

## 4. Catalogue

Cookbook fournit **2 catégories d'agents**, une par dossier — règle *un rôle = un fichier* + install **exclusif** via `bootstrap-claude.sh --stack=none|adonisjs` (zero redondance) :

- **Rôles génériques opus (10 personas)** — `.claude/agents/roles/`, cross-stack, miroir wasabeef (installé en mode `--stack=none`)
- **Stack AdonisJS (7 experts)** — `.claude/agents/stacks/adonisjs/`, couches 1-5 stack-aware qui **héritent + durcissent** les rôles équivalents (installé en mode `--stack=adonisjs` avec 6 roles/ conservés = 13 agents total)

Mapping override complet : [`inheritance-map.md`](inheritance-map.md).

### Vue d'ensemble

```
┌──────────────────────────────────────────────────────────────────┐
│  RÔLES GÉNÉRIQUES OPUS — 10 personas cross-stack                 │
│  .claude/agents/roles/                                           │
│                                                                  │
│    analyzer          — Root cause 5 Whys + hypothèses ranked     │
│    architect         — Evidence-First conception + MECE          │
│    backend           — API RESTful, microservices, cloud-native  │
│    frontend          — WCAG 2.1, design systems, Core Web Vitals │
│    mobile            — iOS HIG + Android Material, cross-platform│
│    performance       — Core Web Vitals + RAIL, profil ROI-driven │
│    product-strategist — Strategic gate différenciation (couche 0)│
│    qa                — Test pyramid + coverage + TDD             │
│    reviewer          — Générique code review (hors stack)        │
│    security          — OWASP Top 10 + OWASP LLM + STRIDE         │
├──────────────────────────────────────────────────────────────────┤
│  STACK ADONISJS — 7 experts en 5 couches                         │
│  .claude/agents/stacks/adonisjs/                                 │
│                                                                  │
│  Couche 1 — ARCHITECT (sonnet)                                   │
│    back-architect        (front-architect = projet-specific)     │
│  Couche 2 — CROSS-CUTTING (sonnet/haiku)                         │
│    security-multitenant + data-access-reviewer (haiku)           │
│    + migration-reviewer                                          │
│  Couche 3 — DOMAIN (sonnet)                                      │
│    workflow-email                                                │
│    (autres = projet-specific : compta, marketplace, public…)     │
│  Couche 4 — LINTER (haiku)                                       │
│    edge-anti-patterns                                            │
│  Couche 5 — FINAL GATE (sonnet)                                  │
│    code-reviewer                                                 │
└──────────────────────────────────────────────────────────────────┘
```

**Quand utiliser stack vs rôle générique ?**

Le choix est fait **au bootstrap**, pas à l'invocation : `--stack=none` installe 10 roles/, `--stack=adonisjs` installe 6 roles/ conservés + 7 stacks/adonisjs/ durcis. Pas de coexistence stack + rôle overridé — la redondance est un anti-pattern (2 experts qui se marchent dessus, ambiguïté d'invocation).

- **Mode `--stack=adonisjs`** : les 7 experts stack sont invoqués automatiquement par description-trigger sur les fichiers AdonisJS. Les 6 rôles conservés (`analyzer`, `frontend`, `mobile`, `performance`, `product-strategist`, `qa`) restent invocables pour leur scope cross-stack.
- **Mode `--stack=none`** : seuls les 10 rôles génériques sont disponibles. Utile pour projets non-Adonis ou audit purement cross-stack.
- **Combinable** : `/multi-agent <path> back-architect,security-multitenant` (mode adonisjs) OU `/multi-agent <path> architect,security` (mode none).

Voir [`inheritance-map.md`](inheritance-map.md) pour le mapping complet override et la logique d'héritage.

**Ordre d'invocation type** :
- **Nouvelle feature** : `product-strategist` (couche 0) AVANT tout. Si verdict NO-GO → on ne code pas. Si GO → architects → cross-cutting → domain → linter → **`code-reviewer` (couche 5) AVANT git commit**.
- **Edit existant** : architect (`back-architect` ou front-architect projet-specific si présent) → cross-cutting pertinents → domain si touché → linter haiku en parallèle → **`code-reviewer` AVANT git commit**.
- **Bugfix / refactor** : skip couche 0, dispatch couches 1-4 → **`code-reviewer` AVANT git commit**.

La couche 0 ne s'invoque pas sur bugfix/refactor pur.
La couche 5 s'invoque **toujours** avant `git commit` si diff non-trivial (≥ 2 fichiers OU ≥ 50 lignes OU touche app/middleware/migrations/routes).

### 4.1 Subagents cookbook (`.claude/agents/roles/*.md` + `.claude/agents/stacks/adonisjs/*.md`)

#### Couche 0 — Strategic gate

| Expert | Model | Source(s) référentiel | Scope (description-trigger) | Tools |
|---|---|---|---|---|
| **`product-strategist`** | sonnet | `PRODUCT.md` OU `docs/product.md` OU `docs/vision.md` du projet + `docs/competitive-benchmark/*.md` (si présent) + `docs/ux-audit-prompt.md` §test 60s | À invoquer AVANT toute nouvelle feature (skill `/feature <nom>` ou auto-trigger sur "ajoute X", "on doit avoir X"). Pose 7 questions canoniques (problème user, benchmark concurrents, différenciation, alignement produit, test 60s, simplifie/ajoute, anti-références). Verdict strict : GO différentiant / REVOIR / NO-GO / BLOCKED-SETUP | Read, Grep, Glob, WebFetch, WebSearch |

> **product-strategist** est la **gate d'entrée** de toute nouvelle feature. Pas de bugfix ni refactor. Si NO-GO, on ne code pas. Si les sources produit du projet sont absentes → verdict `BLOCKED-SETUP` (pas GO par défaut). WebFetch/WebSearch lui permettent de rafraîchir les fiches concurrentes.

#### Couche 1 — Architects

| Expert | Model | Source(s) référentiel | Scope | Tools |
|---|---|---|---|---|
| **`back-architect`** | sonnet | `CLAUDE.md` §3/§8/§14 + `docs/architecture.md` du projet + `docs/feature-plan-template.md` + `scripts/check-file-sizes.js` + `docs/anti-patterns.md` §Architecture | Edit/Write sur `app/controllers/**`, `app/services/**`, `app/middleware/**`, `app/validators/**`, `app/models/**`, `start/routes.ts` — audit conventions AdonisJS, tailles fichier 300/400L, split patterns, helpers `_helpers/`, naming PascalCase, validators Vine, routes ordering | Read, Grep, Glob, Bash |

> **back-architect** est le miroir back d'un éventuel front-architect projet-specific. Conventions structurelles, naming, file size, split patterns. Il **NE FAIT PAS** sécurité, ORM, business rules — il délègue à la couche 2 ou 3. Garde-fou anti-drift inscrit dans son frontmatter.
>
> Si le projet est UI-heavy, ajouter un front-architect projet-specific dans `.claude/agents/` (le cookbook n'en fournit pas, chaque projet a sa charte visuelle).

#### Couche 2 — Cross-cutting

| Expert | Model | Source(s) référentiel | Scope | Tools |
|---|---|---|---|---|
| **`security-multitenant`** | sonnet | `docs/security-multitenant.md` du projet + `docs/anti-patterns.md` §Sécurité + `scan-secu.sh` §22A-F + `CLAUDE.md` §11/§12/§13 | Edit/Write sur `app/controllers/**`, `app/services/**`, `app/middleware/**`, ajout routes `start/routes.ts` — audit multi-tenant : `effectiveUserId`, IDOR via `.firstOrFail()`, CSRF, soft-delete, signed URLs, branding loader public | Read, Grep, Bash |
| **`data-access-reviewer`** | haiku | `docs/database-neon.md` + `docs/storage-s3.md` + `CLAUDE.md` §10/§10b du projet | Edit/Write sur `app/services/**`, `app/models/**`, Lucid queries, raw SQL, S3 storage, Redis cache — grep-pass rapide anti-patterns ORM/storage (preload vs load, save loop, raw SQL ${}, pool min/max, drive.use direct, TTL Redis) | Read, Grep |
| **`migration-reviewer`** | sonnet | `CLAUDE.md` §9/§10 + `docs/anti-patterns.md` §ORM + `docs/database-neon.md` du projet | Add/Edit `database/migrations/**/*.ts` — audit §9 DO/DON'T (IF NOT EXISTS, DEFAULT NOT NULL, JSONB documenté, ALTER CONSTRAINT enum, prepare/consume, index sur FK) | Read, Grep, Glob |

> **`data-access-reviewer`** est **haiku** (rapide, économe) : greps ciblés. Complémentaire au `back-architect` (structure) et `security-multitenant` (isolation) — les 3 tournent en parallèle post-edit sur un fichier service/model.
> **`migration-reviewer`** flagge automatiquement les tables sensibles domaine pour cross-review avec un domain-expert projet-specific s'il existe (compta, marketplace, etc.).

#### Couche 3 — Domain

| Expert | Model | Source(s) référentiel | Scope | Tools |
|---|---|---|---|---|
| **`workflow-email`** | sonnet | Doc workflow projet (typique : `docs/workflows.md`) + doc email projet (typique : `docs/emails.md`) + `CLAUDE.md` §5 (domain glossary) + `docs/anti-patterns.md` §Edge | Edit/Write sur `app/services/**workflow*`, `app/services/**email*`, `app/services/**mail*`, `resources/views/emails/**`, `app/models/workflow*` — audit variable interpolation (Mustache Edge vs ICU JSON), `mail.send()` sync lifecycle vs `sendLater()` async, workflow binding owner_type enum, single-source variable context builder | Read, Grep, Glob |

**Extension projet-specific** : le cookbook fournit `workflow-email` comme exemple domain générique. Chaque projet peut ajouter ses domain experts dans `.claude/agents/` (ex : compta NF525, marketplace commission, subscription/quota, public/subdomain routes, etc.) — cf `docs/claude-config/skills.md` §"Convention d'ajout".

#### Couche 4 — Linters (haiku)

| Expert | Model | Source(s) référentiel | Scope | Tools |
|---|---|---|---|---|
| **`edge-anti-patterns`** | haiku | `CLAUDE.md` §13 + `docs/anti-patterns.md` §Edge/Alpine | Edit/Write sur `resources/views/**/*.edge` — single-pass grep contre 16-23 patterns P0/P1 (Alpine `@click` in partial, `{{{ JSON.stringify` in x-data, `||` in `@each`, ICU vs Mustache lang, etc.). Sortie silencieuse si aucun finding. | Read, Grep |

> **`edge-anti-patterns`** = fast linter haiku, économique. Complémentaire d'un éventuel front-architect projet-specific : les 2 tournent en parallèle sur edit `.edge`.

#### Couche 5 — Final gate

| Expert | Model | Source(s) référentiel | Scope | Tools |
|---|---|---|---|---|
| **`code-reviewer`** | sonnet | `CLAUDE.md` §13/§14 + `docs/anti-patterns.md` du projet + docs domain selon scope + sortie `scan-secu.sh` | AVANT `git commit` si diff non-trivial (≥ 2 fichiers, ≥ 50L, touche app/middleware/migrations/routes). Review PR-style senior : intention, cohérence cross-fichiers, synthèse outils existants, verdict **SHIP / NEEDS CHANGES / REJECT**. Délègue deep-dives aux experts spécialisés (couches 2-3). | Read, Grep, Glob, Bash |

> **`code-reviewer`** est **orchestrateur**, pas linter. Il **lance** `scan-secu.sh` et **lit** sa sortie, il ne re-greppe pas ce que scan-secu fait. Il **délègue** les deep-dives (NF525, charte, multi-tenant approfondi) aux experts couche 2/3. Ne minimise aucun finding, verdict ferme.

### 4.1b Subagents génériques opus opt-in

Cross-stack, non-Adonis-specific. Distincts des core cookbook. Activables via description-trigger OU explicitement via `/multi-agent` skill.

| Expert | Model | Rôle | Complémentaire à |
|---|---|---|---|
| **`architect`** | opus | Conception Evidence-First + MECE, phased migration, sélection tech | `back-architect` (Adonis conventions) |
| **`backend`** | opus | API RESTful/GraphQL, microservices, cloud-native, résilience patterns | `back-architect` (Adonis conventions) |
| **`frontend`** | opus | WCAG 2.1 AA, design systems, Core Web Vitals, mobile-first | `edge-anti-patterns` (grep Edge/Alpine) |
| **`mobile`** | opus | iOS HIG + Android Material, cross-platform (RN/Flutter), offline-first, touch UX | — |
| **`performance`** | opus | Core Web Vitals + RAIL, profilage, optim ROI-driven (mesure avant optim) | `data-access-reviewer` (ORM patterns) |
| **`qa`** | opus | Test pyramid (unit/integration/E2E), coverage critique, TDD, automation | — |
| **`security`** | opus | OWASP Top 10 + OWASP LLM Top 10, CVE, threat modeling STRIDE/PASTA, Zero Trust | `security-multitenant` (Adonis tenant isolation) |
| **`reviewer`** | opus | Générique code review (lisibilité, maintenabilité, cohérence, refactor) | `code-reviewer` (couche 5 stack-aware, orchestrateur) |
| **`analyzer`** | opus | Root cause investigation (5 Whys + hypothèses ranked + reproduction obligatoire) | `/fix-error` skill (petit scope, fix rapide) |

**Quand invoquer un générique opus vs core ?**
- Core d'abord si stack matche (AdonisJS) — projet-aware prime
- Générique opus si perspective wide requise (ex: OWASP LLM sur code IA, MECE cross-team, refactor sans stack conventions)
- Combinables via `/multi-agent`

### 4.2 Skills (`.claude/skills/*/SKILL.md`)

| Skill | Rôle | Enchaînement interne |
|---|---|---|
| `/feature <nom>` | Nouvelle feature — orchestrateur | `superpowers:brainstorming` → `product-strategist` (couche 0) → `superpowers:writing-plans` → dispatch experts couches 1-3 selon scope → implém → `code-reviewer` (couche 5) → closure |
| `/ux-review <page>` | Audit UX d'un écran | 6 axes UX + density gate + principe central produit du projet |
| `/secu` | Wrapper `scan-secu.sh` | Lance scan-secu → parse FAIL/WARN → propose fix par étape |
| `/pre-pr` | Vérification pré-PR | lint → typecheck → build → file-size ratchet → verdict READY/NOT READY |
| `/multi-agent <path> <experts>` | Dispatch parallèle N experts | Mode PARALLEL (union findings) OU DEBATE (dialectique 2-rounds) |

### 4.3 Commands (`.claude/commands/*.md`)

Slash commands productivity user-invoquées.

| Command | Rôle |
|---|---|
| `/commit` | Conventional Commits sur staged, discipline cookbook (pas --no-verify, pas amend, review si non-trivial) |
| `/semantic-commit` | Split gros diff en N commits sémantiques cohérents |
| `/pr-create` | PR draft + auto-select labels + preserve PULL_REQUEST_TEMPLATE.md |
| `/pr-review` | Review PR existante (own ou reçue), invoque experts, classification must/imo/nits/q |
| `/pr-fix` | Répondre aux comments review, approche 3-étapes (reproduire → root cause → fix ciblé) |
| `/plan` | Mode plan explicite pour refactor/archi/infra (complémentaire `/feature`) |
| `/refactor` | Refactor incrémental discipliné (tests verts avant/après, limite §14, baseline ratchet regen) |
| `/fix-error` | Diagnostic + fix erreur, 3 étapes (reproduire → root cause → fix), `--preventive` ajoute leçon |
| `/explain-code` | Explique code (intent + flow + data + edge cases + callers), levels beginner/intermediate/expert |
| `/analyze-dependencies` | Matrice modules + détection cycles + fan-in/fan-out + dead code |
| `/analyze-performance` | Bottlenecks + Core Web Vitals + reco rankées ROI (délègue agent `performance`) |
| `/check-fact` | Vérif claim vs codebase (anti-hallucination), verdicts CORRECT/INCORRECT/PARTIEL/INCONNU |
| `/tech-debt` | Dashboard santé projet + impact temporel + roadmap phasée |

### 4.4 Hooks (`.claude/hooks/*.sh`)

| Hook | Événement | Rôle |
|---|---|---|
| `dispatch-expert.sh` | PostToolUse Edit/Write/MultiEdit | Grep P0 sur path édité → exit 2 si match (BLOCK) + hints stderr layered pour inviter Claude à invoquer les experts pertinents |
| `precommit-check.sh` | PreToolUse Bash (`git commit`) | Détecte staged files → conditionnellement lance typecheck + `check-file-sizes.js` → suggère `code-reviewer` si diff non-trivial |
| `preserve-file-permissions.sh` | PreToolUse + PostToolUse Edit/Write/MultiEdit | Snapshot chmod avant edit, restore après (fix chmod loss macOS/Linux) |

**Extension point** : les projets peuvent ajouter `.claude/hooks/dispatch-expert.local.sh` (sourcé si présent par `dispatch-expert.sh`) pour hints projet-specific vers domain experts custom.

### 4.5 Permissions (`settings.json` racine cookbook)

| Type | Contenu |
|---|---|
| `allow` | Bash, Edit, Read, Write, MultiEdit, Grep, Glob, LS, Task*, WebFetch, WebSearch |
| `deny` | Actions destructives : `rm -rf`, `chmod 777`, force push, reset --hard, `--no-verify`, install globaux, `Write(/.env*)`, etc. Cf `settings.json`. |
| `statusLine` | `scripts/statusline.sh` — model + $/jour (ccusage) + %tokens |
| `hooks` | Wire des 3 hooks via `${CLAUDE_PLUGIN_ROOT}` |

Les permissions **user-scoped ad-hoc** s'accumulent dans `~/.claude/settings.json` ou `.claude/settings.local.json` du projet (non versionné). Utiliser le skill built-in `fewer-permission-prompts` pour nettoyer périodiquement.

### 4.6 MCP servers (`.mcp.json` racine cookbook)

Template avec 4 servers pertinents cross-projet :

| Server | Rôle |
|---|---|
| `context7` | Recherche documentation technique (via `@upstash/context7-mcp`) |
| `sequential-thinking` | Réflexion step-by-step structured (via `@modelcontextprotocol/server-sequential-thinking`) |
| `fetch` | HTTP fetch générique (via `uvx mcp-server-fetch`) |
| `github` | GitHub API (via `@modelcontextprotocol/server-github`), token via `${GITHUB_PERSONAL_ACCESS_TOKEN}` env |

Extension : chaque projet peut ajouter ses MCP servers (Notion, Slack, DB, etc.) dans son `.mcp.json`.

### 4.7 Config Conventional Commits + linting

| Fichier | Rôle |
|---|---|
| `commitlint.config.js` | Enforcement Conventional Commits (types, subject rules ≤ 72 chars, case, etc.) |
| `lefthook.yml` | Git hooks orchestrator — commit-msg (commitlint) + pre-commit (scan-secu delta + file-size ratchet) |
| `.markdownlint.json` | Style markdown consistent (line length 200, siblings only H, etc.) |
| `package.json` | devDeps (commitlint, lefthook, markdownlint) + scripts (`prepare` = lefthook install, `lint:md`) |

Install dans projet :
```bash
npm i -D @commitlint/cli @commitlint/config-conventional lefthook markdownlint-cli
npx lefthook install
```

### 4.8 CI cookbook self-test (`.github/workflows/cookbook-self-test.yml`)

Workflow GitHub Actions qui teste le cookbook lui-même à chaque push :

| Job | Vérifie |
|---|---|
| `bash-lint` | `bash -n` syntax + shellcheck error-only sur tous les `.sh` |
| `json-validate` | `jq empty` sur tous les `.json` |
| `agents-frontmatter` | YAML frontmatter valide (name + description) sur tous les agents `.md` |
| `skills-frontmatter` | Idem pour skills `SKILL.md` |
| `scan-secu-self` | `scan-secu.sh --diff` tourne jusqu'au verdict sans crash |
| `leak-check` | Grep noms projet-specific → doit retourner 0 hors fichiers autorisés |

---

## 5. Mapping path → expert (dispatcher)

Le hook `dispatch-expert.sh` implémente ce mapping. Résumé pour Claude :

| Path modifié | Architect | Cross-cutting | Domain (si expert projet-specific installé) | Linter |
|---|---|---|---|---|
| `resources/views/**/*.edge` | front-architect projet-specific si présent | — | — | `edge-anti-patterns` |
| `resources/css/**`, `resources/js/**` | front-architect projet-specific si présent | — | — | — |
| `resources/lang/*/*.json` | — | — | `workflow-email` (si emails ou i18n Mustache/ICU) | — |
| `app/controllers/**/*.ts` | `back-architect` | `security-multitenant` | selon nom (workflow / email / compta / etc.) | — |
| `app/services/**/*.ts` | `back-architect` | `security-multitenant` + `data-access-reviewer` | selon nom | — |
| `app/models/**/*.ts` | `back-architect` | `data-access-reviewer` | domain-expert projet-specific si table sensible | — |
| `database/migrations/**/*.ts` | — | `migration-reviewer` | domain-expert projet-specific si table sensible | — |
| `app/middleware/**/*.ts` | `back-architect` | `security-multitenant` | selon nom | — |
| `start/routes.ts` | `back-architect` | `security-multitenant` | domain-expert projet-specific si nouvelle route sensible | — |

Le hook émet des hints stderr layered. Les blocs domain-specific sont dans le fichier extension `.claude/hooks/dispatch-expert.local.sh` (créé par le projet).

---

## 6. Sources de vérité par expert (rappel)

### `back-architect`
- `CLAUDE.md` §3/§8/§14 du projet
- `docs/architecture.md` du projet
- `docs/feature-plan-template.md`
- `scripts/check-file-sizes.js` + baseline
- `docs/anti-patterns.md` §Architecture

### `security-multitenant`
- `docs/security-multitenant.md` du projet
- `docs/anti-patterns.md` §Sécurité
- `scan-secu.sh` §22A-F output
- `CLAUDE.md` §11/§12/§13

### `data-access-reviewer`
- `docs/database-neon.md` du projet
- `docs/storage-s3.md` du projet
- `CLAUDE.md` §10/§10b

### `migration-reviewer`
- `CLAUDE.md` §9/§10
- `docs/anti-patterns.md` §ORM
- `docs/database-neon.md`

### `workflow-email`
- Doc workflow projet (typique `docs/workflows.md`)
- Doc email projet (typique `docs/emails.md`)
- `CLAUDE.md` §5 (domain glossary)
- `docs/anti-patterns.md` §Edge

### `edge-anti-patterns`
- `CLAUDE.md` §13
- `docs/anti-patterns.md` §Edge/Alpine

### `product-strategist`
- `PRODUCT.md` OU `docs/product.md` du projet
- `docs/vision.md`, `docs/roadmap.md` (si présents)
- `docs/competitive-benchmark/*.md` (si présent)
- `docs/ux-audit-prompt.md` §test 60s

### `code-reviewer`
- `CLAUDE.md` §13/§14
- `docs/anti-patterns.md`
- Docs domain selon scope
- Sortie `scan-secu.sh` du run courant

---

## 7. Maintenance du catalogue

### Ajouter un subagent domain projet-specific

1. Vérifier qu'aucun expert existant ne couvre déjà le besoin (anti-duplication)
2. Créer `.claude/agents/<name>.md` avec frontmatter `name/description/tools/model` — descriptif **actif** ("Use PROACTIVELY when…", pas "Specialized in…")
3. Charge sa source de vérité **dédiée** (doc projet)
4. Format sortie standardisé P0/P1/Quick wins/Déjà correct
5. Ajouter au dispatcher : si patterns grepables → étendre `.claude/hooks/dispatch-expert.local.sh` du projet
6. Si générique (cross-project) : proposer copie vers cookbook

### Ajouter un skill

1. Vérifier qu'il ne recouvre pas un subagent existant (skill = invocation **humaine**, subagent = invocation **Claude auto**)
2. Créer `.claude/skills/<name>/SKILL.md` avec frontmatter `name/description`
3. Documenter la source de vérité (fichier `docs/*.md` que le skill doit charger)
4. Ajouter au catalogue `docs/claude-config/skills.md`

### Ajouter un pattern P0 au hook

1. Vérifier que c'est **grepable** (sinon → subagent)
2. Ajouter le case au bon path-branch dans `dispatch-expert.sh`
3. Fournir en stderr : message clair `[hook:<class>-P0] BLOCKED — <pattern> dans <file> — solution. Cf <source>.`
4. Tester : Edit volontaire → confirmation exit 2
5. Documenter dans `CLAUDE.md` §13 anti-patterns du projet

---

## 8. Cadence de review

- **Trimestriel** : audit usage des skills/agents (quels ont été invoqués, combien de fois, quels findings) — ajuster descriptions-trigger si sur/sous-invocation
- **Après chaque incident sécurité/qualité** : identifier si un hook P0 aurait bloqué, si un expert aurait catch — sinon, ajouter la règle
- **Après chaque évolution majeure de Claude Code** : re-vérifier compatibilité hooks (format JSON input/output, matchers, etc.)
