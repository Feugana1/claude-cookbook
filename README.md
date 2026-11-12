# Claude Code Cookbook

Harness Claude Code pour projets **Node / TypeScript** (packs AdonisJS et Expo / React Native inclus). Un **core** générique (agents experts, skills, hook pre-commit, scan sécurité tiered OWASP, prod-readiness, templates) et des **packs de stack** qui durcissent le core.

**Statut** : version dans `plugins/core/.claude-plugin/plugin.json` — distribuable comme **plugin Claude Code natif** ou via `bootstrap-claude.sh` (fallback).

---

## Flux quotidien

Trois mécanismes, trois déclencheurs. L'humain tape les skills ; les agents et les hooks se déclenchent seuls.

| Moment | Tu tapes | Se déclenche seul |
| --- | --- | --- |
| Nouvelle feature | `/feature` | `product-strategist` rend GO / REVOIR / NO-GO ; sans GO, pas de code |
| Pendant le code | rien | experts auto-dispatchés d'après leur `description` (architecte, sécurité, données, linter) ; hook pack bloque les patterns P0 sur Edit/Write |
| Avant commit | `/pre-pr` puis `/commit` | hook pre-commit analyse le diff staged et suggère `reviewer` / `code-reviewer` ; `--no-verify` refusé par permission |
| Avant push / PR | `/secu` puis `/pr` | `scan-secu.sh` (delta en pre-commit, full avant push, cron hebdo en CI) |
| Audit ponctuel | `/multi-agent`, `/refactor`, `/prod-readiness`, `/ai-config`, `/ux-review` (pack) | — |

Règles : un expert dit **REJECT** → on corrige, on ne contourne pas. Pas de `--no-verify`. Un hook bloque légitimement → `// canonical-skip:<rule>:<reason>` dans le diff.

Liste et comptes : `bash scripts/inventory.sh`. Catalogue par couche : [`docs/claude-config/experts.md`](docs/claude-config/experts.md).

---

## Inventory

Comptes générés depuis le filesystem (jamais écrits à la main) :

```bash
bash scripts/inventory.sh          # tableau
bash scripts/inventory.sh --json   # machine-readable
```

---

## Structure

Un marketplace, deux plugins : un **core** générique et des **packs de stack** optionnels.

```
.claude-plugin/marketplace.json      déclare cookbook-core + un plugin par pack de stack

plugins/
├── core/                            générique, aucune mention de stack
│   ├── .claude-plugin/plugin.json   source unique de la version
│   ├── agents/                      rôles génériques (1 fichier par use case)
│   ├── skills/                      /feature /pre-pr /secu /commit /pr /refactor /multi-agent /ai-config /prod-readiness
│   ├── hooks/                       precommit-check
│   └── scripts/                     scan-secu.sh + scan-secu.d/ (steps génériques),
│                                    scan-ai-config, scan-prod-readiness, sbom, statusline
└── adonisjs/                        pack optionnel, dépend de cookbook-core
    ├── .claude-plugin/plugin.json
    ├── agents/                      experts stack-aware (couches 1-5)
    ├── skills/                      /ux-review (Edge)
    ├── hooks/                       dispatch-expert (patterns P0 Adonis)
    └── scripts/                     steps scan-secu Edge/Lucid/Adonis, check-file-sizes.js
└── expo/                            pack optionnel (Expo / React Native), même structure
    ├── agents/                      experts mobile (architecture, sécurité MASVS, perf, review)
    ├── hooks/                       dispatch-expert (patterns P0 mobiles)
    └── scripts/                     steps scan-secu mobiles (stockage, EXPO_PUBLIC_, cleartext…)

bootstrap-claude.sh                  fallback : copie core (+ pack) dans un projet
scripts/inventory.sh                 comptes générés depuis le filesystem
docs/                                lessons, anti-patterns, templates, claude-config/
commitlint.config.js  lefthook.yml  .markdownlint.json   outillage du cookbook
```

Le layout **installé** dans un projet cible : `.claude/agents/roles/` (agents core), `.claude/agents/stacks/<stack>/` (agents du pack), `.claude/{skills,hooks}`, `scripts/`, `scan-secu.sh`.
Dans les docs, « agent core » et « agent pack » désignent ces deux dossiers.

Ajouter une stack = créer `plugins/<stack>/` (mêmes sous-dossiers que `adonisjs`) + une entrée dans `marketplace.json`. Aucune modification du core.

**Plugin vs bootstrap** : installer `cookbook-core` + `cookbook-adonisjs` en plugin donne *tous* les agents, y compris les rôles génériques que le pack durcit (`architect` et `back-architect` coexistent). Seul `bootstrap-claude.sh --stack=adonisjs` retire les rôles remplacés (zéro redondance).

---

## Installation

### Voie A — Plugin natif Claude Code (recommandé)

```bash
# Depuis n'importe où :
/plugin marketplace add <owner>/claude-cookbook
/plugin install cookbook-core@claude-cookbook
/plugin install cookbook-adonisjs@claude-cookbook   # optionnel : pack AdonisJS
/plugin install cookbook-expo@claude-cookbook       # optionnel : pack Expo / React Native
```

Le plugin fournit agents, skills et hooks (`hooks/hooks.json`). Il ne livre pas de règles `permissions` (un `settings.json` de plugin n'applique que `agent` et `subagentStatusLine`) : voir [`setup.md`](docs/claude-config/setup.md).

### Voie B — Bootstrap script (fallback)

Depuis le dossier de ton nouveau projet :

```bash
bash $COOKBOOK_DIR/bootstrap-claude.sh . [--stack=none|<pack>] [--update] [--dry-run] [--force] [--with-git-tooling]
```

**Choix stack (exclusif — zero redondance)** :

| Mode | Install |
|---|---|
| `--stack=none` (défaut CI non-TTY) | tous les agents core |
| `--stack=adonisjs` | agents core non remplacés + agents du pack (`pack.conf` → `REPLACES`) |
| `--stack=expo` | agents core non remplacés + agents du pack (app mobile) |

Les stacks disponibles sont les dossiers `plugins/*/` qui contiennent un `pack.conf`. Sans `--stack` en TTY : menu généré depuis ces packs ; hors TTY : `none`. Le mapping override roles ↔ stacks est documenté dans le README de chaque pack : [`plugins/adonisjs/README.md`](plugins/adonisjs/README.md), [`plugins/expo/README.md`](plugins/expo/README.md).

Installe `.claude/` (agents, skills, hooks, `settings.json`), `scripts/`, `docs/`, `.mcp.json` + un `CLAUDE.md` minimal à enrichir. L'outillage git (commitlint, lefthook, markdownlint) est opt-in : `--with-git-tooling`.

### Mise à jour dans un projet existant

```bash
bash $COOKBOOK_DIR/bootstrap-claude.sh . --update --dry-run   # voir ce qui changerait
bash $COOKBOOK_DIR/bootstrap-claude.sh . --update
```

- **Fichiers gérés** (agents, skills, hooks, scripts, docs de référence) : mis à jour **seulement s'ils sont restés tels que le cookbook les a installés**. L'empreinte de chaque fichier installé est notée dans `.claude/.cookbook-manifest` (à commiter). Un fichier adapté par le projet, ou présent sans empreinte (installation antérieure au manifeste), est conservé et signalé avec la commande `diff` à lancer ; `--force` l'écrase. Toute version remplacée est sauvegardée dans `.claude/.cookbook-backup/<horodatage>/`.
- **Fichiers du projet** (`CLAUDE.md`, `.claude/settings.json`, `.mcp.json`, `docs/lessons.md`, `docs/anti-patterns.md`, docs du pack) : **jamais écrasés** ; le script signale ceux qui diffèrent de la version cookbook.
- **Fichiers retirés du cookbook** (`plugins/core/retired.txt`) et fichiers d'un pack non retenu : sauvegardés puis supprimés (changement de stack propre), sauf s'ils ont été adaptés par le projet.
- `scripts/scan-secu.d/` n'est installé que si le `scan-secu.sh` du projet charge ces étapes : un `scan-secu.sh` monolithique adapté reste seul.
- **Chemins refusés par le projet** : listés dans `.claude/.cookbook-ignore` (à commiter), un motif glob par ligne (`*` couvre aussi `/`, `#` commente), ex. `docs/templates/*`. Le bootstrap ne les ajoute, ne les met à jour ni ne les retire, même avec `--force`. Sans cette liste, un fichier supprimé à la main revient au `--update` suivant.
- Tes agents, skills et commands maison ne sont jamais touchés.

---

## Architecture agents — flux cohérent, zero redondance

Règles :
1. **Un rôle = un fichier** (miroir [wasabeef/claude-code-cookbook](https://github.com/wasabeef/claude-code-cookbook/tree/main/plugins/fr/agents/roles))
2. **Générique OU stack, jamais les deux** pour un même use case (bootstrap install exclusif)
3. **Stack durcit rôle** : quand un agent du pack remplace un agent core, il hérite conceptuellement de son scope (règle d'or, format sortie) puis durcit avec les conventions stack

### Catalogue d'agents

Un rôle = un fichier. Un agent core et son override pack ne sont **jamais installés ensemble**. Catalogue par couche : [`docs/claude-config/experts.md`](docs/claude-config/experts.md). Mapping override : README de chaque pack ([`adonisjs`](plugins/adonisjs/README.md), [`expo`](plugins/expo/README.md)).

### Ajouter une stack

Voir « Ajouter une stack » dans [`plugins/adonisjs/README.md`](plugins/adonisjs/README.md) : un dossier `plugins/<stack>/` avec son `pack.conf`, une entrée marketplace ; le bootstrap découvre le pack seul. Le core ne change pas.

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
- `docs/dev-changelog.md` si le projet veut un journal des features livrées (closure de `/feature`) ; sinon la closure note dans `docs/lessons.md`
- Agents domain projet-specific (compta, marketplace, workflow custom, subscription, public routes, front-architect si UI-heavy, etc.)
- Extension hook `.claude/hooks/dispatch-expert.local.sh` (sourcé si présent — pour hints domain-specific)

---

## Pour les agents Claude Code

→ Lire [AGENTS.md](AGENTS.md) pour comprendre comment opérer ce cookbook.
