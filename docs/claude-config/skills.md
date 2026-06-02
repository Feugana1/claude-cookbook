# Skills — inventaire

> Liste des skills Claude Code utilisés (built-in + projet + externes).
> Catalogue cible et règles d'usage : [`experts.md`](experts.md).

## Skills built-in (livrés avec Claude Code)

Disponibles par défaut, sans installation. Inventaire :

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

## Skills installés en local au projet (`.claude/skills/`)

### État actuel (2026-05-30 — post R01→R17)

| Skill | Path | Trigger | Source de vérité | Subagent associé |
|---|---|---|---|---|
| `/feature <nom>` | `.claude/skills/feature/SKILL.md` | **AVANT toute nouvelle feature non-triviale** | [`PRODUCT.md`](../../PRODUCT.md) + [`docs/vision.md`](../vision.md) + [`docs/competitive-benchmark/`](../competitive-benchmark/) | `product-strategist` (orchestre puis dispatch experts couches 1-3) |
| `/ux-review <page>` | `.claude/skills/ux-review/SKILL.md` | Avant add-feature config, "ça paraît dense" | [`docs/ux-audit-prompt.md`](../ux-audit-prompt.md) + [`docs/design-system.md`](../design-system.md) | `front-curator` (peut être délégué pour audit profond) |
| `/secu` | `.claude/skills/secu/SKILL.md` | Avant `git push`, modifs sensibles | [`scan-secu.sh`](../../scan-secu.sh) (24 étapes) | `security-multitenant` pour deep-dive sur FAIL |
| `/pre-pr` | `.claude/skills/pre-pr/SKILL.md` | Avant créer PR | `npm run lint/typecheck`, [`scripts/check-file-sizes.js`](../../scripts/check-file-sizes.js) | — (purement séquence shell) |

Tous versionnés via R01 (whitelist `.gitignore`). Cf [`experts.md` §9](experts.md#9-roadmap--état-dimplémentation).

> Le subagent `code-reviewer` (couche 5) est **auto-invoqué avant `git commit`** par le hook `precommit-check.sh` qui suggère son invocation en stderr. Il n'a pas de skill slash dédié — l'invocation est gérée par la description-trigger de l'agent.

### Skills backlog

| Skill | Trigger | Statut |
|---|---|---|
| `/nf525-check` | Avant merge feature compta | À FAIRE (R09c) |
| `/wf-scaffold <action\|trigger>` | Nouveau trigger/action workflow | À FAIRE (R09d) |
| `/ux-review` `references/` | Progressive disclosure (sortir 50% inline) | À FAIRE (R08b) |

## Plugins marketplace (`~/.claude/plugins/`)

Liste source : `docs/claude-config/settings/installed-plugins.json`. Réinstall via `/plugin install <name>@<source>`.

| Plugin | Source | Skills exposés |
|---|---|---|
| `caveman@caveman` | GitHub `JuliusBrussee/caveman` | `caveman`, `caveman-commit`, `caveman-review` — communication ultra-compressée |

Marketplace officiel cloné mais **0 plugin activé** : `~/.claude/plugins/marketplaces/claude-plugins-official/` (36 plugins disponibles). Candidats potentiels à évaluer (cf [`experts.md` §9 R14](experts.md#9-roadmap--état-dimplémentation)) :
- `code-review` — recouvre partiellement `security-multitenant` + `front-curator`
- `security-guidance` — recouvre partiellement `scan-secu.sh`
- `hookify` — assistant création hooks
- `claude-md-management` — gestion CLAUDE.md
- `skill-creator` — création skills

## Convention d'ajout

Avant d'ajouter un nouveau skill :

1. Vérifier qu'il ne recouvre pas un subagent existant (cf [`experts.md` §4.1](experts.md#41-subagents-projet-claudeagentsmd)) — un skill = invocation **humaine** explicite, un subagent = invocation **Claude auto**
2. Choisir le bon scope (skill projet `.claude/skills/` vs plugin marketplace vs built-in)
3. Documenter la source de vérité (fichier `docs/*.md` que le skill doit charger)
4. Ajouter une ligne ici + entrée dans [`docs/dev-changelog.md`](../dev-changelog.md)
