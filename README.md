# Claude Code Cookbook

Stack Claude Code générique pour projets **AdonisJS / Node / TypeScript**. Sub-agents en 2 dossiers (`roles/` génériques opus + `stacks/adonisjs/` couches 1-5), skills, commands, hooks P0 déterministes, scan sécurité tiered OWASP, anti-patterns catalogués, templates prêts à wire.

**Statut** : v0.2.0 — distribuable comme **plugin Claude Code natif** ou via `bootstrap-claude.sh` (fallback).

---

## Inventory

| Composant | Count | Path |
|---|---|---|
| **Roles génériques opus** (cross-stack, 1 fichier par use case) | **10** | `.claude/agents/roles/*.md` |
| **Sub-agents stack AdonisJS** (couches 1-5, sonnet/haiku) | **7** | `.claude/agents/stacks/adonisjs/*.md` |
| **Skills** (invocation humaine explicite) | **7** | `.claude/skills/*/SKILL.md` |
| **Commands** (slash commands) | **13** | `.claude/commands/*.md` |
| **Hooks** (déclenchés automatiquement) | **3** | `.claude/hooks/*.sh` |
| **scan-secu.sh steps** (tier OWASP T1/T2/T3) | **41** | `scripts/scan-secu.d/step-*.sh` |
| **scan-ai-config.sh standards** (P0/P1/P2 gap analysis) | **18** | `scripts/scan-ai-config.sh` |
| **prod-readiness capabilities V0** (security / reliability / observability / delivery / data) | **32** | `.claude/skills/prod-readiness/capabilities/*.yaml` |
| **Templates scaffold** (CLAUDE, AGENTS, PRODUCT, architecture, anti-patterns, lessons, mcp.json + wire) | **10** | `docs/templates/*` |
| **Config** (permissions + MCP + statusline + commitlint + lefthook + markdownlint) | **6** | racine |

Total : **~50 fichiers**, ~7000 lignes de méthodologie distillée.

---

## Structure

```
.claude-plugin/
├── marketplace.json    manifest marketplace (1 plugin déclaré : cookbook)
└── plugin.json         manifest plugin cookbook v0.2.0

.claude/
├── agents/
│   ├── roles/          10 rôles génériques opus (1 fichier par use case, miroir wasabeef)
│   │                   analyzer, architect, backend, frontend, mobile, performance,
│   │                   product-strategist, qa, reviewer, security
│   └── stacks/
│       └── adonisjs/   7 experts stack-aware (couches 1-5, sonnet/haiku)
│                       back-architect, code-reviewer, data-access-reviewer,
│                       edge-anti-patterns, migration-reviewer, security-multitenant,
│                       workflow-email
├── skills/             5 slash commands (/feature, /pre-pr, /secu, /ux-review, /multi-agent)
├── commands/           13 productivity commands (/commit, /pr-*, /refactor, /explain-code, /tech-debt, ...)
└── hooks/              3 hooks (dispatch-expert + precommit-check + preserve-file-permissions)

settings.json           permissions deny larges + hooks wire + env + statusLine
.mcp.json               MCP servers template (Context7 + sequential-thinking + fetch + github)
commitlint.config.js    Conventional Commits enforcement
lefthook.yml            git hooks orchestrator (commit-msg + pre-commit)
.markdownlint.json      markdown style consistent
package.json            devDeps + scripts

scripts/
├── scan-secu.sh        orchestrator ~220L (helpers + counters + verdict + --diff mode)
│                       Modes : --full (pre-push, 2-3min) | --diff [<base>] (pre-commit, ~3s)
│                       SECU_DIFF_STAGED=1 pour scan git diff --cached (pre-commit hook)
├── scan-secu.d/        41 stateless step modules sourced in order (tier OWASP T1/T2/T3)
│                       Drop a `step-NN-<slug>.sh` → TOTAL auto-bumps
├── check-file-sizes.js ratchet CI tailles fichiers (controllers/services/templates)
├── generate-sbom.sh    CycloneDX 1.6 SBOM front + back
└── statusline.sh       statusline model + $/jour (ccusage) + %tokens

docs/templates/
├── .gitleaks.toml           allowlist test fixtures + local dev + historical commits
├── husky-pre-commit.sh      wire scan-secu --diff en pre-commit (~3s)
└── scan-secu-weekly.yml     cron GH Actions lundi 06:00 UTC + issue auto Tier-1

docs/
├── lessons.md              Karpathy 4 disciplines + leçons process (template générique)
├── anti-patterns.md        Catalogue exhaustif anti-patterns Edge/Alpine/AdonisJS/ORM/sécu
├── feature-plan-template.md Template unifié spec + plan + completeness (~200L max)
│                            Inclut §1b EARS notation + §3b threat model T1-T18
├── ux-audit-prompt.md      6 axes audit UX (User-first, PLG, DS, restraint cognitif…)
└── claude-config/          Catalogue agents (roles/ + stacks/adonisjs/), setup cross-poste, superpowers integration

.github/workflows/
└── cookbook-self-test.yml  CI cookbook lui-même (bash-lint, JSON/YAML valid, frontmatter, scan-secu no-crash, leak-check)
```

---

## Installation

### Voie A — Plugin natif Claude Code (recommandé)

```bash
# Depuis n'importe où :
/plugin marketplace add <owner>/claude-cookbook
/plugin install cookbook@claude-cookbook
```

Wire automatique : hooks + permissions + agents + skills + commands + MCP + statusline.

### Voie B — Bootstrap script (fallback)

Depuis le dossier de ton nouveau projet :

```bash
bash ~/dev/claude-cookbook/bootstrap-claude.sh . [--stack=none|adonisjs] [--update]
```

**Choix stack (exclusif — zero redondance)** :

| Mode | Install | Total agents |
|---|---|---|
| `--stack=none` (défaut CI non-TTY) | `roles/*` (10 génériques opus) | 10 |
| `--stack=adonisjs` | 6 `roles/` conservés + 7 `stacks/adonisjs/` durcis | 13 |

Sans `--stack` en TTY interactif : le script propose un menu. Le mapping override roles ↔ stacks est documenté dans [`docs/claude-config/inheritance-map.md`](docs/claude-config/inheritance-map.md).

Copie `.claude/`, `.claude-plugin/`, `scripts/`, `docs/`, `settings.json`, `.mcp.json` dans le projet courant + crée `CLAUDE.md` minimal à enrichir.

### Mise à jour dans un projet existant

```bash
bash ~/dev/claude-cookbook/bootstrap-claude.sh . --update
```

Mode update : écrase uniquement les fichiers du cookbook, ne touche pas aux fichiers spécifiques projet (`CLAUDE.md`, agents custom, hooks override, etc.).

---

## Architecture agents — flux cohérent, zero redondance

Règles :
1. **Un rôle = un fichier** (miroir [wasabeef/claude-code-cookbook](https://github.com/wasabeef/claude-code-cookbook/tree/main/plugins/fr/agents/roles))
2. **Générique OU stack, jamais les deux** pour un même use case (bootstrap install exclusif)
3. **Stack durcit rôle** : quand un fichier `stacks/adonisjs/X` remplace un `roles/Y`, il hérite conceptuellement de son scope (règle d'or, format sortie) puis durcit avec les conventions stack

### 1. Roles génériques opus — 10 personas (mode `--stack=none`)

Un rôle = un use case. Utilisables partout, quel que soit le framework.

| Rôle | Use case | Model |
|---|---|---|
| `analyzer` | Root cause 5 Whys + hypothèses ranked | opus |
| `architect` | Conception Evidence-First + MECE + phased migration | opus |
| `backend` | API RESTful/GraphQL, microservices, cloud-native | opus |
| `frontend` | WCAG 2.1, design systems, Core Web Vitals | opus |
| `mobile` | iOS HIG + Android Material, cross-platform, offline-first | opus |
| `performance` | Core Web Vitals + RAIL + profilage ROI-driven | opus |
| `product-strategist` | Strategic gate différenciation feature (couche 0) | sonnet |
| `qa` | Test pyramid + coverage + TDD + automation | opus |
| `reviewer` | Générique code review lisibilité/maintenabilité | opus |
| `security` | OWASP Top 10 + OWASP LLM + threat modeling STRIDE | opus |

### 2. Stack AdonisJS — 7 experts stack-aware (mode `--stack=adonisjs`)

Experts qui **héritent** des rôles génériques équivalents et **durcissent** avec les conventions §14 (300/400/800L limits), multi-tenant Adonis, ORM Lucid, etc.

```
Couche 1 ARCHITECT       : back-architect             ← remplace roles/architect + roles/backend
Couche 2 CROSS-CUTTING   : security-multitenant       ← remplace roles/security
                           data-access-reviewer (haiku) — pur ajout (aucun rôle équivalent)
                           migration-reviewer          — pur ajout
Couche 3 DOMAIN          : workflow-email              — pur ajout
Couche 4 LINTER          : edge-anti-patterns (haiku)  — PAIR avec roles/frontend (linter narrow)
Couche 5 FINAL GATE      : code-reviewer              ← remplace roles/reviewer     ← avant git commit
```

**En mode `adonisjs`** : `roles/architect`, `roles/backend`, `roles/security`, `roles/reviewer` **ne sont PAS installés** (leur override stack prend le relais). Conservés : `analyzer`, `frontend`, `mobile`, `performance`, `product-strategist`, `qa` (aucun override AdonisJS).

Mapping complet : [`docs/claude-config/inheritance-map.md`](docs/claude-config/inheritance-map.md).

### Ajouter une stack

Créer `.claude/agents/stacks/<votre-stack>/` (ex : `laravel/`, `nextjs/`, `django/`), déposer les experts stack-aware, ajouter le mapping dans `inheritance-map.md`, ajouter le mode `--stack=<votre-stack>` dans `bootstrap-claude.sh`. Les rôles génériques `roles/` restent utilisables tels quels.

---

## Wiring scan-secu — 3 surfaces (delta / full / cron)

Le scan couvre 3 moments distincts, chacun avec un scope adapté :

**1. Pre-commit hook — delta (~3s)**

```bash
# .husky/pre-commit (copie depuis docs/templates/husky-pre-commit.sh)
SECU_DIFF_STAGED=1 bash scan-secu.sh --diff || exit 1
node scripts/check-file-sizes.js || exit 1
```

Scope : fichiers `git diff --cached` uniquement. Skip Trivy/typecheck/npm audit/build/SBOM (whole-repo). Lint delta-scoped. Gitleaks `protect --staged`.

**2. Pre-push manuel — full (2-3min)**

```bash
bash scan-secu.sh --full   # tout, incluant Trivy + history gitleaks + SBOM
```

**3. CI cron hebdo — catch la dette qui se cache loin**

```bash
# .github/workflows/scan-secu-weekly.yml (copie depuis docs/templates/scan-secu-weekly.yml)
# Cron lundi 06:00 UTC + workflow_dispatch. Upload rapport 90j.
# Création issue auto (label scan-secu-weekly + security) si régression Tier-1.
```

Motivation : delta pre-commit rate les régressions dans les fichiers jamais touchés depuis 6 mois (deps outdated, license drift, historical secret leak). Cron hebdo comble.

**Bonus — `.gitleaks.toml`** (copie depuis `docs/templates/.gitleaks.toml`) : allowlist paths (`.env*` local dev, `.env.test`, `docs/api.md`, fixtures) + commits historiques rotated + regex placeholders.

---

## Source de vérité — où enrichir

**Modèle a — recommandé court terme** : enrichir dans un projet actif, exporter périodiquement vers le cookbook via copie sélective. Les patterns émergent en prod, le cookbook fige les bonnes pratiques.

**Modèle b — long terme** : enrichir directement le cookbook, importer dans projets via bootstrap `--update` ou re-install plugin. Plus rigoureux mais demande discipline de sync.

---

## Ce qui n'est PAS dans le cookbook (à ajouter par chaque projet)

Le cookbook est **générique**. Chaque projet doit fournir :

- `PRODUCT.md` (vision produit) et/ou `docs/vision.md`, `docs/roadmap.md`
- `docs/competitive-benchmark/*.md` (si `product-strategist` utilisé)
- Docs domain : `docs/architecture.md`, `docs/design-system.md`, `docs/database-neon.md`, `docs/storage-s3.md`, `docs/security-multitenant.md`, etc.
- Agents domain projet-specific (compta, marketplace, workflow custom, subscription, public routes, front-architect si UI-heavy, etc.)
- Extension hook `.claude/hooks/dispatch-expert.local.sh` (sourcé si présent — pour hints domain-specific)

---

## Pour les agents Claude Code

→ Lire [AGENTS.md](AGENTS.md) pour comprendre comment opérer ce cookbook.
