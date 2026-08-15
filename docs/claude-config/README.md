# Claude Code — configuration projet

> Documentation de la configuration Claude Code utilisée pour MyProject :
> philosophie, catalogue d'experts spécialisés en 6 couches, procédure de reproduction cross-poste.

## État (2026-05-30)

| Item | Volumétrie | Statut |
|---|---|---|
| Subagents experts | 12 (10 sonnet + 2 haiku) | ✅ versionnés `.claude/agents/` |
| Skills | 4 (`/feature`, `/ux-review`, `/secu`, `/pre-pr`) | ✅ versionnés `.claude/skills/` |
| Hooks | 2 (`dispatch-expert.sh`, `precommit-check.sh`) | ✅ versionnés `.claude/hooks/` |
| Settings projet | `.claude/settings.json` permissions deny/ask + hooks | ✅ versionné |
| Référentiel concurrents | 13 fichiers (5 enrichis + 8 squelette) | ✅ `docs/competitive-benchmark/` |
| Roadmap | R01→R17 P0/P1 livrés | ✅ Détail [`experts.md` §9](experts.md#9-roadmap--état-dimplémentation) |

Backlog résiduel : R08b (`/ux-review` references/), R09c (`/nf525-check`), R09d (`/wf-scaffold`), R10 (`~/.claude/CLAUDE.md`), R11 (clean `settings.local.json`), enrichissement des 8 squelettes concurrents.

## Structure de cette doc

| Fichier | Rôle |
|---|---|
| [`experts.md`](experts.md) | **Doc maître** — démarche d'automatisation, catalogue 6 couches, règle d'or "expert prend le dessus sans complaisance", roadmap R01→R17 |
| [`setup.md`](setup.md) | Procédure step-by-step pour reproduire sur un nouveau poste (pré-requis, login, snapshot, vérifications) |
| [`skills.md`](skills.md) | Inventaire des skills installés (built-in Claude Code + projet) |
| `settings/user-settings.json` | Snapshot sanitized de `~/.claude/settings.json` (paths normalisés `<PROJECT_ROOT>`) |
| `settings/installed-plugins.json` | Snapshot de `~/.claude/plugins/installed_plugins.json` |

Référentiels associés (versionnés mais hors `claude-config/`) :

| Path | Rôle |
|---|---|
| [`docs/competitive-benchmark/`](../competitive-benchmark/) | 13 concurrents (Pixieset, Pic-Time, Honeybook, Tave, Studio Ninja, 17hats, Iris Works, ShootProof, Sprout Studio, Cloudspot, Unscripted, Picflow, Pelli) — source de `product-strategist` |
| [`docs/lessons.md`](../lessons.md) | Leçons projet (Karpathy 4 + orchestration agentic + anti-patterns process) — chargé par CLAUDE.md §17 |
| [`docs/anti-patterns.md`](../anti-patterns.md) | Catalogue exhaustif d'anti-patterns (Edge/Alpine/ORM/sécurité/architecture) |

## Philosophie en 3 lignes

Une instruction CLAUDE.md est consultative (suivie ~80 %). Une règle dure doit être déterministe :
**hook** (grep + exit 2), **permission deny**, ou **subagent expert** chargé sur sa propre source de vérité.
Détail complet et catalogue 6 couches : [`experts.md`](experts.md).

## Catalogue 6 couches (résumé)

```
Couche 0 STRATEGIC GATE  : product-strategist        ← avant toute nouvelle feature
Couche 1 ARCHITECTS       : front-curator | back-architect
Couche 2 CROSS-CUTTING    : security-multitenant | data-access-reviewer (haiku) | migration-reviewer
Couche 3 DOMAIN           : nf525-accounting | shop-marketplace | workflow-email | public-experience
Couche 4 LINTERS          : edge-anti-patterns (haiku)
Couche 5 FINAL GATE       : code-reviewer           ← avant git commit
```

Chaque expert applique la **règle d'or** : sources chargées AVANT analyse, STAY IN SCOPE, sans complaisance, cite `file:line`, format sortie standardisé, tests internes de validation.

## Reproduction sur un nouveau poste

Procédure complète : [`setup.md`](setup.md).

TL;DR :

```bash
git clone <repo> && cd myproject-repo && npm ci
claude login
cp docs/claude-config/settings/user-settings.json ~/.claude/settings.json
# Réinstaller les plugins listés dans settings/installed-plugins.json
```

Note : depuis R01 (refactor `.gitignore` whitelist), `.claude/{agents,skills,commands,hooks,settings.json}` sont **versionnés dans le repo** — `git clone` suffit pour récupérer tout le catalogue. Seul reste manuel : la conf `~/.claude/` user (préférences cross-projet).

## Ce qui n'est PAS dans le snapshot

- `.credentials.json` — token API personnel (jamais commit)
- `~/.claude/cache/`, `debug/`, `history.jsonl`, `sessions/`, `telemetry/` — runtime/historique local
- `.claude/settings.local.json` — permissions ad-hoc accumulées par usage (reconstruit naturellement)

## Quoi est versionné dans le repo

| Path | Versionné ? | Statut |
|---|---|---|
| `.claude/agents/*.md` (12 subagents) | OUI | ✅ FAIT 2026-05-30 |
| `.claude/skills/*/SKILL.md` (4 skills) | OUI | ✅ FAIT 2026-05-30 |
| `.claude/commands/*.md` | OUI (whitelist) | aucun pour l'instant |
| `.claude/hooks/*.sh` (2 hooks) | OUI | ✅ FAIT 2026-05-30 |
| `.claude/settings.json` (projet) | OUI | ✅ FAIT 2026-05-30 |
| `.claude/settings.local.json` | NON | gitignore stable |
| `docs/claude-config/**` | OUI | ce dossier |
| `docs/competitive-benchmark/**` | OUI | référentiel `product-strategist` |
| `docs/lessons.md` | OUI | leçons projet (CLAUDE.md §17) |

## Synchronisation snapshot

Quand `~/.claude/settings.json` ou les plugins user changent :

```bash
sed 's|/Users/[^/]*/Documents/dev/myproject-repo|<PROJECT_ROOT>|g' \
   ~/.claude/settings.json > docs/claude-config/settings/user-settings.json
cp ~/.claude/plugins/installed_plugins.json docs/claude-config/settings/installed-plugins.json 2>/dev/null || true
git add docs/claude-config && git commit -m "chore(claude-config): refresh snapshot $(date +%Y-%m-%d)"
```

Pour les évolutions **projet** (`.claude/agents/`, `.claude/hooks/`, `.claude/settings.json`, `docs/competitive-benchmark/`), commit directement — pas de snapshot intermédiaire.

## Quand un concurrent évolue

Workflow recommandé :
1. Le subagent `product-strategist` détecte que `lastAudit > 3 mois` ou qu'une feature impactée touche un concurrent
2. WebFetch sur `roadmapUrl` du concurrent pour rafraîchir
3. Mise à jour `docs/competitive-benchmark/<concurrent>.md` (frontmatter `lastAudit:` + sections impactées)
4. Si shift majeur (release majeur type Pic-Time 2.0) → entrée datée `docs/dev-changelog.md`
