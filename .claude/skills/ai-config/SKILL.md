---
name: ai-config
description: Scan la configuration Claude Code du projet vs standards cookbook (18 items P0/P1/P2), identifie les gaps, et propose un scaffold interactif des fichiers manquants depuis docs/templates/. Use PROACTIVELY quand user dit "audit config claude", "scan ai config", "quels standards me manquent", "setup claude sur ce projet", "/ai-config". Auto-trigger quand session démarre sur repo sans CLAUDE.md OU AGENTS.md OU .claude/agents/.
---

# Skill `/ai-config`

Audit + scaffold de la configuration IA du projet (Claude Code standards). Cible : projets qui installent le cookbook (via plugin ou bootstrap) OU projets qui construisent leur config from scratch.

## Ce que ça fait

1. **Scan** : lance `bash scripts/scan-ai-config.sh` (18 items, tier P0/P1/P2) — 100% read-only
2. **Rapport** : verdict par item PRESENT / PARTIAL / MISSING avec evidence
3. **Verdict global** : NEEDS BOOTSTRAP (P0 manquant) | PARTIAL | COMPLET
4. **Scaffold interactif** : propose de créer les fichiers manquants depuis `docs/templates/`

## Standards vérifiés (18 items)

### P0 — Foundation (bloquant)

| Item | Path | Template |
|---|---|---|
| CLAUDE.md (project instructions) | `CLAUDE.md` | `docs/templates/CLAUDE.md` |
| .claude/agents/ (any expert) | `.claude/agents/` | via `bootstrap-claude.sh --stack=X` |
| settings.json (Claude Code config) | `settings.json` OU `.claude/settings.json` | cookbook root `settings.json` |

### P1 — Recommandé

| Item | Path | Template |
|---|---|---|
| AGENTS.md (Claude operating manual) | `AGENTS.md` | `docs/templates/AGENTS.md` |
| PRODUCT.md (product vision) | `PRODUCT.md` OU `docs/vision.md` | `docs/templates/PRODUCT.md` |
| docs/architecture.md | `docs/architecture.md` | `docs/templates/architecture.md` |
| docs/anti-patterns.md | `docs/anti-patterns.md` | `docs/templates/anti-patterns.md` |
| docs/lessons.md | `docs/lessons.md` | `docs/templates/lessons.md` |
| .mcp.json (MCP servers config) | `.mcp.json` | `docs/templates/mcp.json` |
| .claude/skills/ (any skill) | `.claude/skills/` | via bootstrap |
| .claude/commands/ (any command) | `.claude/commands/` | via bootstrap |
| .claude/hooks/dispatch-expert.sh | `.claude/hooks/dispatch-expert.sh` | via bootstrap |
| scripts/scan-secu.sh | `scripts/scan-secu.sh` | via bootstrap |

### P2 — Nice-to-have

| Item | Path | Template |
|---|---|---|
| docs/feature-plan-template.md | `docs/feature-plan-template.md` | cookbook `docs/` |
| docs/ux-audit-prompt.md | `docs/ux-audit-prompt.md` | cookbook `docs/` |
| commitlint.config.js | `commitlint.config.js` | cookbook root |
| lefthook.yml | `lefthook.yml` | cookbook root |
| .github/workflows/ (CI) | `.github/workflows/` | (à créer selon stack) |

## Méthode

### Étape 1 — Scan read-only

```bash
bash scripts/scan-ai-config.sh
```

Sortie : rapport human-readable coloré + code exit :
- `0` = COMPLET
- `1` = PARTIAL (P1/P2 manquants)
- `2` = NEEDS BOOTSTRAP (P0 manquant)

Version JSON pour parsing programmatique :

```bash
bash scripts/scan-ai-config.sh --json
```

### Étape 2 — Rapport à l'utilisateur

Format :

```
## Scan AI Config — Résumé

Verdict : <NEEDS BOOTSTRAP | PARTIAL | COMPLET>
Score : X/18 présent (Y partial, Z manquant)

### P0 manquants (bloquants)
- ✗ <item> — <evidence>

### P1 manquants (recommandés)
- ✗ <item>

### P2 manquants (nice)
- ✗ <item>
```

### Étape 3 — Prompt scaffold interactif

**Si verdict = COMPLET** : rien à faire, féliciter, proposer de lancer `/pre-pr` ou `/secu`.

**Si verdict = PARTIAL ou NEEDS BOOTSTRAP** : demander à l'utilisateur :

> "X item(s) manquant(s). Créer les fichiers manquants depuis les templates ?
>
> 1. **P0 uniquement** — juste ce qui est bloquant (recommandé si session commence)
> 2. **Tous P0+P1** — foundation complète
> 3. **Cherry-pick** — choisir un par un
> 4. **Non** — juste garder le rapport"

### Étape 4 — Scaffold (si accepté)

Pour chaque fichier à créer :

1. Copier depuis `docs/templates/<file>` vers path cible
2. Confirmer création : `+ <path>`
3. **Ne PAS écraser** si le fichier existe (sauf si l'user demande `--force`)

Mapping template → cible :

```
docs/templates/CLAUDE.md        →  CLAUDE.md
docs/templates/AGENTS.md        →  AGENTS.md
docs/templates/PRODUCT.md       →  PRODUCT.md
docs/templates/architecture.md  →  docs/architecture.md
docs/templates/anti-patterns.md →  docs/anti-patterns.md
docs/templates/lessons.md       →  docs/lessons.md
docs/templates/mcp.json         →  .mcp.json
```

Pour les items foundation via bootstrap (`.claude/agents/`, `.claude/skills/`, `.claude/commands/`, `.claude/hooks/`, `scripts/scan-secu.sh`, `settings.json`, `commitlint.config.js`, `lefthook.yml`) :

Proposer à l'user :
> "Foundation cookbook manquante. Lancer le bootstrap ?
> `bash $COOKBOOK_DIR/bootstrap-claude.sh . --stack=<adonisjs|none>`"

Ne pas lancer bootstrap automatiquement — c'est une action à confirmer par l'user (stack choice).

### Étape 5 — Post-scaffold

Après création, **rappeler** ce qu'il faut personnaliser :

- `CLAUDE.md` §5 Domain Model Glossary — remplir PRIMARY_MODELS
- `PRODUCT.md` §1 Problème résolu — écrire la vraie vision produit
- `AGENTS.md` §Stack — spécifier stack cible + mode cookbook
- `docs/architecture.md` §2 Stack technique — remplir versions
- `docs/anti-patterns.md` — vider les exemples génériques + remplir avec anti-patterns du projet
- `docs/lessons.md` §5 — vider et enrichir au fil de l'eau

Proposer de relancer `/ai-config` après pour vérifier PARTIAL → COMPLET.

## Anti-patterns à éviter

- ❌ Créer les fichiers sans demander l'user (intrusif)
- ❌ Écraser un fichier existant sans warning
- ❌ Lancer `bootstrap-claude.sh` sans confirmer le mode stack
- ❌ Skipper le prompt même en mode "auto" — l'user doit choisir
- ❌ Copier les templates tel quels sans rappeler les personnalisations
- ❌ Marquer un item PARTIAL comme PRESENT après scaffold — c'est PARTIAL jusqu'à personnalisation

## Cas d'usage typiques

### Nouveau projet (rien n'existe)

1. `/ai-config` → verdict NEEDS BOOTSTRAP
2. User choisit "P0 uniquement" ou lance bootstrap
3. Après bootstrap → relancer `/ai-config` → PARTIAL
4. Choisir "Tous P0+P1" pour compléter docs
5. Éditer les fichiers créés (personnalisation §5)

### Projet cookbook installé mais docs pas remplies

1. `/ai-config` → verdict PARTIAL
2. Score : 15/18 présent, PRODUCT.md + docs/architecture.md manquants
3. Cherry-pick ces 2 items → scaffold
4. Rappel : éditer PRODUCT.md §1 avec la vraie vision

### Audit avant handoff

1. `/ai-config` → verdict COMPLET
2. Confirmer que la config est propre avant de handoff le projet à quelqu'un

## Références

- Script sous-jacent : `scripts/scan-ai-config.sh`
- Templates : `docs/templates/*`
- Bootstrap : `bootstrap-claude.sh` (pour la foundation)
- Cookbook `docs/claude-config/inheritance-map.md` — mapping roles ↔ stacks (comprendre `--stack=adonisjs|none`)
- Cookbook `docs/claude-config/experts.md` — catalogue agents
