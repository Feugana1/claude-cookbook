# Skills + commands — inventaire

> Liste des skills + commands Claude Code utilisés (built-in + cookbook + externes).
> Catalogue cible et règles d'usage : [`experts.md`](experts.md) §4.2/§4.3.

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

**6 skills invocables via `/<name>`** :

| Skill | Path | Trigger | Source de vérité | Subagent associé |
|---|---|---|---|---|
| `/ai-config` | `.claude/skills/ai-config/SKILL.md` | Nouveau projet, "audit config claude", session sans CLAUDE.md/AGENTS.md | `scripts/scan-ai-config.sh` (18 standards P0/P1/P2) + `docs/templates/*` | — (scaffold interactif) |
| `/feature <nom>` | `.claude/skills/feature/SKILL.md` | **AVANT toute nouvelle feature non-triviale** | `PRODUCT.md` OU `docs/product.md` du projet + `docs/competitive-benchmark/` si présent | `product-strategist` (orchestre puis dispatch experts couches 1-3) |
| `/ux-review <page>` | `.claude/skills/ux-review/SKILL.md` | Avant add-feature config, "ça paraît dense" | `docs/ux-audit-prompt.md` + `docs/design-system.md` du projet | front-architect projet-specific si présent (peut être délégué pour audit profond) |
| `/secu` | `.claude/skills/secu/SKILL.md` | Avant `git push`, modifs sensibles | `scan-secu.sh` (41 étapes tier OWASP) | `security-multitenant` pour deep-dive sur FAIL |
| `/pre-pr` | `.claude/skills/pre-pr/SKILL.md` | Avant créer PR | `npm run lint/typecheck`, `scripts/check-file-sizes.js` | — (purement séquence shell) |
| `/multi-agent <path> [experts]` | `.claude/skills/multi-agent/SKILL.md` | Audit exhaustif fichier / diff | Dispatch parallèle N experts (mode PARALLEL ou DEBATE) | Multiple experts cookbook |

Tous versionnés dans le cookbook. Le subagent `code-reviewer` (couche 5) est **auto-invoqué avant `git commit`** par le hook `precommit-check.sh` qui suggère son invocation en stderr — pas de skill slash dédié.

## Commands installés par le cookbook (`.claude/commands/`)

**13 commands slash productivity** :

| Command | Rôle | Complémentaire à |
|---|---|---|
| `/commit` | Conventional Commits sur staged, discipline cookbook (pas --no-verify, pas amend) | `code-reviewer` couche 5 (invoqué si diff non-trivial) |
| `/semantic-commit` | Split gros diff en N commits sémantiques cohérents | `/commit` (unique commit) |
| `/pr-create` | Crée PR draft, auto-select labels, preserve template | `/pre-pr` (précède) |
| `/pr-review` | Review PR existante (own ou reçue), classification must/imo/nits/q | `/multi-agent` (dispatch experts) |
| `/pr-fix` | Répondre aux comments review, 3 étapes reproduire→root→fix | `/commit` (nouveau commit par fix batch) |
| `/plan` | Mode plan explicite pour refactor/archi/infra | `/feature` (features product-facing) |
| `/refactor` | Refactor incrémental discipliné, ratchet regen | `back-architect` (audit conventions post) |
| `/fix-error` | Diagnostic + fix erreur 3 étapes, `--preventive` add leçon | `analyzer` agent (root cause deep-dive) |
| `/explain-code` | Explique code : intent + flow + data + edge cases + callers | — |
| `/analyze-dependencies` | Matrice modules + cycles + fan-in/out + dead code | `architect` agent (deep-dive) |
| `/analyze-performance` | Bottlenecks + Core Web Vitals + reco rankées ROI | `performance` agent (deep-dive) |
| `/check-fact` | Vérif claim vs codebase (anti-hallucination) | — |
| `/tech-debt` | Dashboard santé projet + impact temporel + roadmap phasée | `architect`/`security`/`qa` (deep-dive) |

### Skills projet-specific (à ajouter par le projet, non fournis par cookbook)

Selon le domaine du projet, envisager :

| Skill | Trigger | Quand |
|---|---|---|
| `/<domain>-check` | Avant merge feature domaine | Si projet a un expert domain (compta, marketplace, workflow custom) qui gagne à être invoqué via slash court |
| `/wf-scaffold <action\|trigger>` | Nouveau trigger/action workflow | Si projet a un système de workflows configurables |

## Plugins marketplace complémentaires

Le cookbook lui-même est distribuable comme plugin (`.claude-plugin/plugin.json`). Complémentaires recommandés :

| Plugin | Source | Skills exposés | Utilité |
|---|---|---|---|
| `superpowers` | `claude-plugins-official` | 14 skills discipline session (brainstorming, writing-plans, systematic-debugging, etc.) | Discipline process — cf [`superpowers-integration.md`](superpowers-integration.md) |
| `caveman` (opt) | GitHub `JuliusBrussee/caveman` | `caveman`, `caveman-commit`, `caveman-review` — communication ultra-compressée | Économie tokens (~75%) |

## Skills vs Commands — distinction

**Skill** (`.claude/skills/<name>/SKILL.md`) :
- Dossier + SKILL.md + optionnellement `references/`, `scripts/`
- Frontmatter : `name`, `description`
- Peut être complexe, orchestrer plusieurs sous-étapes, avoir des references docs
- Ex : `/feature` orchestre brainstorming + strategist + writing-plans + dispatch experts

**Command** (`.claude/commands/<name>.md`) :
- 1 seul fichier markdown
- Frontmatter : `description`
- Généralement plus simple, workflow linéaire ou wrapping outil
- Ex : `/commit` = workflow commit discipliné

**Règle** : si scope requiert references + sub-scripts → skill. Sinon → command.

## Convention d'ajout d'un nouveau skill/command

Avant d'ajouter :

1. Vérifier qu'il ne recouvre pas un subagent existant (cf [`experts.md` §4.1/§4.1b](experts.md)) — un skill/command = invocation **humaine** explicite, un subagent = invocation **Claude auto**
2. Choisir le bon scope :
   - Skill/command cookbook si générique cross-projet
   - Skill/command projet si projet-specific
   - Plugin marketplace si publiable
3. Documenter la source de vérité (fichier `docs/*.md` que le skill doit charger)
4. Ajouter une ligne ici + entrée dans `docs/dev-changelog.md` du projet
5. Si générique : proposer copie vers cookbook
