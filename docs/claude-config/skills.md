# Skills — inventaire

> Liste des skills Claude Code utilisés (built-in + cookbook + externes).
> Catalogue cible et règles d'usage : [`experts.md`](experts.md).

## Skills built-in (livrés avec Claude Code)

Disponibles par défaut, sans installation. Inventaire non-exhaustif (varie selon version) :

| Skill | Description |
|---|---|
| `update-config` | Configure le harness Claude Code via `settings.json` (permissions, hooks, env vars) |
| `keybindings-help` | Customise les raccourcis (`~/.claude/keybindings.json`) |
| `simplify` | Review du code modifié pour réutilisation, qualité, efficacité |
| `fewer-permission-prompts` | Audit et nettoyage de `.claude/settings.json` (allowlist permissions) |
| `loop` | Lance un prompt sur intervalle récurrent |
| `schedule` | Crée/gère des routines distantes (cron) |
| `claude-api` | Build, debug, optimise des apps Claude API / Anthropic SDK |
| `init` | Initialise un CLAUDE.md projet |
| `review` | Review une PR |
| `security-review` | Review sécurité du diff courant |
| `code-review` | Review multi-effort niveau (low → ultra multi-agent cloud) |
| `verify` | Vérifie qu'un change fait vraiment ce qu'il doit |
| `run` | Launch app pour voir un change en action |

## Skills installés par le cookbook (`.claude/skills/`)

| Skill | Path | Trigger | Source de vérité | Subagent associé |
|---|---|---|---|---|
| `/feature <nom>` | `.claude/skills/feature/SKILL.md` | **AVANT toute nouvelle feature non-triviale** | `PRODUCT.md` OU `docs/product.md` du projet + `docs/competitive-benchmark/` si présent | `product-strategist` (orchestre puis dispatch experts couches 1-3) |
| `/ux-review <page>` | `.claude/skills/ux-review/SKILL.md` | Avant add-feature config, "ça paraît dense" | `docs/ux-audit-prompt.md` + `docs/design-system.md` du projet | front-architect projet-specific si présent (peut être délégué pour audit profond) |
| `/secu` | `.claude/skills/secu/SKILL.md` | Avant `git push`, modifs sensibles | `scan-secu.sh` (41 étapes tier OWASP) | `security-multitenant` pour deep-dive sur FAIL |
| `/pre-pr` | `.claude/skills/pre-pr/SKILL.md` | Avant créer PR | `npm run lint/typecheck`, `scripts/check-file-sizes.js` | — (purement séquence shell) |

Tous versionnés dans le cookbook. Le subagent `code-reviewer` (couche 5) est **auto-invoqué avant `git commit`** par le hook `precommit-check.sh` qui suggère son invocation en stderr — pas de skill slash dédié.

### Skills projet-specific (à ajouter par le projet, non fournis par cookbook)

Selon le domaine du projet, envisager :

| Skill | Trigger | Quand |
|---|---|---|
| `/<domain>-check` | Avant merge feature domaine | Si le projet a un expert domain (compta, marketplace, workflow custom) qui gagne à être invoqué via un slash court |
| `/wf-scaffold <action\|trigger>` | Nouveau trigger/action workflow | Si le projet a un système de workflows configurables |

## Plugins marketplace complémentaires

Le cookbook lui-même est distribuable comme plugin (`.claude-plugin/plugin.json`). Complémentaires recommandés :

| Plugin | Source | Skills exposés | Utilité |
|---|---|---|---|
| `superpowers` | `claude-plugins-official` | 14 skills discipline session (brainstorming, writing-plans, systematic-debugging, etc.) | Discipline process — cf [`superpowers-integration.md`](superpowers-integration.md) |
| `caveman` (opt) | GitHub `JuliusBrussee/caveman` | `caveman`, `caveman-commit`, `caveman-review` — communication ultra-compressée | Économie tokens (~75%) |

## Convention d'ajout d'un nouveau skill

Avant d'ajouter un nouveau skill :

1. Vérifier qu'il ne recouvre pas un subagent existant (cf [`experts.md` §4.1](experts.md)) — un skill = invocation **humaine** explicite, un subagent = invocation **Claude auto**
2. Choisir le bon scope :
   - Skill cookbook (`.claude/skills/` du cookbook) si générique cross-projet
   - Skill projet (`.claude/skills/` du projet) si projet-specific
   - Plugin marketplace si publiable
3. Documenter la source de vérité (fichier `docs/*.md` que le skill doit charger)
4. Ajouter une ligne ici + entrée dans `docs/dev-changelog.md` du projet
5. Si générique : proposer copie vers cookbook
