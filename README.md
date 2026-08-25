# Claude Code Cookbook

Stack Claude Code générique pour projets **AdonisJS / Node / TypeScript**. Sub-agents orchestrés en 6 couches, skills, commands, hooks P0 déterministes, scan sécurité tiered OWASP, anti-patterns catalogués, templates prêts à wire.

**Statut** : v0.2.0 — distribuable comme **plugin Claude Code natif** ou via `bootstrap-claude.sh` (fallback).

---

## Inventory

| Composant | Count | Path |
|---|---|---|
| **Sub-agents cookbook** (stack-aware AdonisJS, couches 0-5) | **8** | `.claude/agents/*.md` |
| **Sub-agents génériques opus** (opt-in, cross-stack) | **9** | `.claude/agents/*.md` |
| **Skills** (invocation humaine explicite) | **5** | `.claude/skills/*/SKILL.md` |
| **Commands** (slash commands) | **13** | `.claude/commands/*.md` |
| **Hooks** (déclenchés automatiquement) | **3** | `.claude/hooks/*.sh` |
| **scan-secu.sh steps** (tier OWASP T1/T2/T3) | **41** | `scripts/scan-secu.d/step-*.sh` |
| **Config** (permissions + MCP + statusline + commitlint + lefthook + markdownlint) | **6** | racine |

Total : **~50 fichiers**, ~7000 lignes de méthodologie distillée.

---

## Structure

```
.claude-plugin/
├── marketplace.json    manifest marketplace (1 plugin déclaré : cookbook)
└── plugin.json         manifest plugin cookbook v0.2.0

.claude/
├── agents/             17 sub-agents (8 core stack-aware + 9 generic opus opt-in)
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
└── claude-config/          Catalogue agents (6 couches), setup cross-poste, superpowers integration

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
bash ~/dev/claude-cookbook/bootstrap-claude.sh .
```

Copie `.claude/`, `.claude-plugin/`, `scripts/`, `docs/`, `settings.json`, `.mcp.json` dans le projet courant + crée `CLAUDE.md` minimal à enrichir.

### Mise à jour dans un projet existant

```bash
bash ~/dev/claude-cookbook/bootstrap-claude.sh . --update
```

Mode update : écrase uniquement les fichiers du cookbook, ne touche pas aux fichiers spécifiques projet (`CLAUDE.md`, agents custom, hooks override, etc.).

---

## Architecture agents — 2 catégories

### 1. Core cookbook (stack-aware AdonisJS) — 8 agents en 6 couches

```
Couche 0 STRATEGIC GATE  : product-strategist        ← avant toute nouvelle feature
Couche 1 ARCHITECTS       : back-architect           (front-architect = projet-specific si UI-heavy)
Couche 2 CROSS-CUTTING    : security-multitenant | data-access-reviewer (haiku) | migration-reviewer
Couche 3 DOMAIN           : workflow-email           (autres = projet-specific : compta, marketplace, public, etc.)
Couche 4 LINTERS          : edge-anti-patterns (haiku)
Couche 5 FINAL GATE       : code-reviewer           ← avant git commit
```

### 2. Generic opus (opt-in, cross-stack) — 9 personas

| Agent | Rôle | Complémentaire à |
|---|---|---|
| `architect` | Conception Evidence-First + MECE + phased migration | `back-architect` (stack) |
| `backend` | API RESTful/GraphQL, microservices, cloud-native | `back-architect` |
| `frontend` | WCAG 2.1, design systems, Core Web Vitals | `edge-anti-patterns` |
| `mobile` | iOS HIG + Android Material, cross-platform, offline-first | — |
| `performance` | Core Web Vitals + RAIL + profilage ROI-driven | — |
| `qa` | Test pyramid + coverage + TDD + automation | — |
| `security` | OWASP Top 10 + OWASP LLM + threat modeling STRIDE | `security-multitenant` (Adonis tenant) |
| `reviewer` | Générique code review lisibilité/maintenabilité | `code-reviewer` (couche 5 stack) |
| `analyzer` | Root cause 5 Whys + hypothèses ranked | `/fix-error` (petit scope) |

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
