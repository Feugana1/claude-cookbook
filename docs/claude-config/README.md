# Claude Code — configuration projet (cookbook)

> Documentation de la configuration Claude Code fournie par le cookbook :
> philosophie, catalogue d'experts spécialisés en 6 couches, procédure de reproduction cross-poste.

## Ce que le cookbook installe

| Item | Volumétrie | Statut |
|---|---|---|
| Subagents core (couches 0-5, stack-aware AdonisJS) | 8 (7 sonnet + 1 haiku) | ✅ versionnés `.claude/agents/` |
| Subagents génériques opus (opt-in, cross-stack) | 9 personas (architect, backend, frontend, mobile, performance, qa, security, reviewer, analyzer) | ✅ versionnés `.claude/agents/` |
| Skills | 5 (`/feature`, `/ux-review`, `/secu`, `/pre-pr`, `/multi-agent`) | ✅ versionnés `.claude/skills/` |
| Commands | 13 (`/commit`, `/semantic-commit`, `/pr-create`, `/pr-review`, `/pr-fix`, `/plan`, `/refactor`, `/fix-error`, `/explain-code`, `/analyze-dependencies`, `/analyze-performance`, `/check-fact`, `/tech-debt`) | ✅ versionnés `.claude/commands/` |
| Hooks | 3 (`dispatch-expert.sh`, `precommit-check.sh`, `preserve-file-permissions.sh`) | ✅ versionnés `.claude/hooks/` |
| Settings template | `settings.json` — permissions deny + hooks wire + env + statusLine | ✅ versionné racine cookbook |
| MCP template | `.mcp.json` — Context7 + sequential-thinking + fetch + github | ✅ versionné racine cookbook |
| Config Conventional Commits | `commitlint.config.js` + `lefthook.yml` + `.markdownlint.json` + `package.json` | ✅ versionnés racine |
| Plugin manifest | `.claude-plugin/plugin.json` + `marketplace.json` | ✅ distribution native Claude Code |
| Scripts qualité | `scan-secu.sh` orchestrator + 41 étapes + `check-file-sizes.js` + `generate-sbom.sh` + `statusline.sh` | ✅ versionnés `scripts/` |
| CI self-test | `.github/workflows/cookbook-self-test.yml` | ✅ versionné |

Ce qui reste **à ajouter par chaque projet** (non versionné dans cookbook) :
- `PRODUCT.md` (vision produit)
- `docs/vision.md`, `docs/roadmap.md`, `docs/competitive-benchmark/` (si `product-strategist` utilisé)
- `docs/design-system.md`, `docs/architecture.md`, `docs/database-neon.md`, `docs/storage-s3.md`, `docs/security-multitenant.md` (sources de vérité domain, référencées par les subagents)
- Agents projet-specific (`nf525-accounting`, `shop-marketplace`, etc.) si le domaine du projet le justifie

## Structure de cette doc

| Fichier | Rôle |
|---|---|
| [`experts.md`](experts.md) | **Doc maître** — démarche d'automatisation, catalogue 6 couches, règle d'or "expert prend le dessus sans complaisance" |
| [`setup.md`](setup.md) | Procédure step-by-step pour reproduire sur un nouveau poste (pré-requis, login, vérifications) |
| [`skills.md`](skills.md) | Inventaire des skills installés (built-in Claude Code + cookbook) |
| [`superpowers-integration.md`](superpowers-integration.md) | Matrice routage skills cookbook vs `superpowers@claude-plugins-official` |

## Philosophie en 3 lignes

Une instruction CLAUDE.md est consultative (suivie ~80 %). Une règle dure doit être déterministe :
**hook** (grep + exit 2), **permission deny**, ou **subagent expert** chargé sur sa propre source de vérité.
Détail complet et catalogue 6 couches : [`experts.md`](experts.md).

## Catalogue 6 couches (résumé)

```
Couche 0 STRATEGIC GATE  : product-strategist        ← avant toute nouvelle feature (projet-specific si vision produit doc)
Couche 1 ARCHITECTS       : back-architect           (front-architect = projet-specific si UI-heavy)
Couche 2 CROSS-CUTTING    : security-multitenant | data-access-reviewer (haiku) | migration-reviewer
Couche 3 DOMAIN           : workflow-email           (autres = projet-specific : compta, marketplace, public, etc.)
Couche 4 LINTERS          : edge-anti-patterns (haiku)
Couche 5 FINAL GATE       : code-reviewer           ← avant git commit
```

Chaque expert applique la **règle d'or** : sources chargées AVANT analyse, STAY IN SCOPE, sans complaisance, cite `file:line`, format sortie standardisé, tests internes de validation.

## Reproduction sur un nouveau poste

Deux voies possibles :

### Voie A — Plugin natif Claude Code (recommandé)

```bash
# Ajouter le cookbook comme marketplace
/plugin marketplace add <owner>/claude-cookbook
# Installer le plugin
/plugin install cookbook@claude-cookbook
```

Le plugin auto-wire hooks + permissions + fournit agents/skills.

### Voie B — Bootstrap script (fallback)

```bash
git clone <cookbook-repo> ~/dev/claude-cookbook
cd <mon-projet>
bash ~/dev/claude-cookbook/bootstrap-claude.sh .
```

Copie `.claude/`, `scripts/`, `docs/`, `settings.json` dans le projet cible.

## Ce qui n'est PAS dans le cookbook

- Vision produit projet (`PRODUCT.md`, `docs/vision.md`, benchmark concurrents)
- Docs domain projet (`docs/design-system.md`, `docs/architecture.md`, `docs/accounting.md`, etc.)
- Agents domain projet-specific (compta, marketplace, public routes, subscriptions)
- Secrets, tokens API, `.env`
- `settings.local.json` (permissions ad-hoc accumulées)

## Quand un concurrent évolue (si projet utilise product-strategist)

Workflow recommandé :
1. Le subagent `product-strategist` détecte que `lastAudit > 3 mois` ou qu'une feature impactée touche un concurrent
2. WebFetch sur `roadmapUrl` du concurrent pour rafraîchir
3. Mise à jour `docs/competitive-benchmark/<concurrent>.md` (frontmatter `lastAudit:` + sections impactées)
4. Si shift majeur (release majeur concurrent) → entrée datée `docs/dev-changelog.md`
