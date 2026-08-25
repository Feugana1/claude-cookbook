# Claude Code Cookbook

Stack Claude Code générique pour projets **AdonisJS / Node / TypeScript**. Sub-agents orchestrés en 6 couches, skills, hooks P0 déterministes, scan sécurité tiered OWASP, anti-patterns catalogués, templates prêts à wire.

**Statut** : v0.2.0 — distribuable comme **plugin Claude Code natif** ou via `bootstrap-claude.sh` (fallback).

---

## Qu'est-ce qu'il y a dedans

```
.claude-plugin/
├── marketplace.json    manifest marketplace (1 plugin déclaré : cookbook)
└── plugin.json         manifest plugin cookbook v0.2.0

settings.json           permissions deny larges + hooks wire + env (auto-loaded par Claude Code)

.claude/
├── agents/             8 sub-agents génériques (strategist, code-reviewer, architects, security, workflow-email…)
├── skills/             4 slash commands (/feature, /pre-pr, /secu, /ux-review)
└── hooks/              2 hooks shell (dispatch-expert auto-routing + precommit-check rappel reviewer)

scripts/
├── scan-secu.sh        orchestrator ~220L (helpers + counters + verdict + --diff mode)
│                       Modes : --full (pre-push, 2-3min) | --diff [<base>] (pre-commit, ~3s)
│                       SECU_DIFF_STAGED=1 pour scan git diff --cached (pre-commit hook)
├── scan-secu.d/        41 stateless step modules sourced in order (tier OWASP T1/T2/T3)
│                       Drop a `step-NN-<slug>.sh` → TOTAL auto-bumps
│                       Include gitleaks + env-history-guard + gitignore-env-patterns +
│                       precommit-hook + pentest black-box remediation (38-46 : sourcemaps,
│                       sensitive serialize, presigned TTL, reset tokens invalidation,
│                       session regen, OAuth state, SSRF DNS, quota atomic lock, /health minimal)
├── check-file-sizes.js ratchet CI tailles fichiers (controllers/services/templates)
└── generate-sbom.sh    CycloneDX 1.6 SBOM front + back

docs/templates/
├── .gitleaks.toml           allowlist test fixtures + local dev + historical commits
├── husky-pre-commit.sh      wire scan-secu --diff en pre-commit (~3s)
└── scan-secu-weekly.yml     cron GH Actions lundi 06:00 UTC + issue auto Tier-1

docs/
├── lessons.md              Karpathy 4 disciplines + leçons process (template générique)
├── anti-patterns.md        Catalogue exhaustif anti-patterns Edge/Alpine/AdonisJS/ORM/sécu
├── feature-plan-template.md  Template unifié spec + plan + completeness (~200L max)
│                             Inclut §3b threat model T1-T18 (10 classes originales
│                             + 8 classes post-pentest 2026-07 : Auth lifecycle, OAuth,
│                             Info disclosure, Sensitive serialize, Presigned lifecycle,
│                             CSP hardening, SSRF completeness, GDPR minimization)
├── ux-audit-prompt.md      6 axes audit UX (User-first, PLG, DS, restraint cognitif…)
└── claude-config/          Catalogue agents (6 couches), setup cross-poste, superpowers integration
```

Total : **~30 fichiers, ~5000 lignes** de méthodologie distillée.

---

## Installation

### Voie A — Plugin natif Claude Code (recommandé)

```bash
# Depuis n'importe où :
/plugin marketplace add <owner>/claude-cookbook
/plugin install cookbook@claude-cookbook
```

Wire automatique : hooks + permissions + agents + skills disponibles.

### Voie B — Bootstrap script (fallback)

Depuis le dossier de ton nouveau projet :

```bash
bash ~/dev/claude-cookbook/bootstrap-claude.sh .
```

Copie `.claude/`, `scripts/`, `docs/`, `settings.json` dans le projet courant + crée `CLAUDE.md` minimal à enrichir.

### Mise à jour dans un projet existant

```bash
bash ~/dev/claude-cookbook/bootstrap-claude.sh . --update
```

Mode update : écrase uniquement les fichiers du cookbook, ne touche pas aux fichiers spécifiques projet (`CLAUDE.md`, agents custom, hooks override, etc.).

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
