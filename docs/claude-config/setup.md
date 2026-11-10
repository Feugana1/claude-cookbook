# Setup — installer le cookbook

> Doc canonique d'installation et de vérification. Catalogue d'agents : [`experts.md`](experts.md). Mapping rôles ↔ stack : README du pack (`plugins/<stack>/README.md`, copié en `docs/claude-config/stack-<stack>.md` par le bootstrap).

---

## 0. Pré-requis

| Outil | Vérif |
|---|---|
| Node.js 20+, npm 10+ | `node -v` |
| git 2.40+ | `git --version` |
| Claude Code CLI | `claude --version` |
| `jq` (utilisé par les hooks) | `jq --version` |
| bash 4+ ou zsh | — |

Optionnels pour `scan-secu.sh` complet : `trivy`, `gitleaks`, `jscpd`, `license-checker` (le script skip si absent).

## 1. Installation

### Voie A — Plugin Claude Code

```bash
/plugin marketplace add <owner>/claude-cookbook
/plugin install cookbook-core@claude-cookbook
/plugin install cookbook-adonisjs@claude-cookbook   # optionnel : pack AdonisJS
/plugin install cookbook-expo@claude-cookbook       # optionnel : pack Expo / React Native
```

Un plugin fournit agents, skills et hooks. Ses hooks sont déclarés dans `hooks/hooks.json` de chaque plugin. Il **ne livre pas** de règles `permissions` : seules les clés `agent` et `subagentStatusLine` d'un `settings.json` de plugin sont appliquées. Pour les deny-rules, utiliser la voie B ou copier le bloc `permissions` de `docs/templates/settings.json` dans le `.claude/settings.json` du projet.

### Voie B — Bootstrap script

```bash
export COOKBOOK_DIR=<chemin-du-clone>   # là où tu clones le cookbook
git clone <cookbook-repo> "$COOKBOOK_DIR"

cd <mon-projet>
bash $COOKBOOK_DIR/bootstrap-claude.sh . --stack=adonisjs   # projet AdonisJS/Node/TS
bash $COOKBOOK_DIR/bootstrap-claude.sh . --stack=expo       # app Expo / React Native
bash $COOKBOOK_DIR/bootstrap-claude.sh . --stack=none       # cross-stack universel
# options : --dry-run (aperçu) · --with-git-tooling (commitlint + lefthook + markdownlint)
```

- Sans `--stack` en TTY : menu interactif. En CI non-TTY : défaut `none`.
- Copie `.claude/`, `scripts/`, `docs/` + crée un `CLAUDE.md` minimal à enrichir.
- `--update` : re-synchronise. Fichiers gérés mis à jour avec sauvegarde dans `.claude/.cookbook-backup/`, seulement s'ils correspondent encore à l'empreinte notée dans `.claude/.cookbook-manifest` ; un fichier adapté par le projet est conservé et signalé (`--force` pour l'écraser) ; `CLAUDE.md`, `.claude/settings.json`, `.mcp.json`, `docs/lessons.md`, `docs/anti-patterns.md` jamais écrasés ; chemins listés dans `.claude/.cookbook-ignore` (motifs glob) jamais ajoutés, mis à jour ni retirés.
- Changer de stack avec `--update --stack=<autre>` retire proprement les fichiers de l'ancien pack (sauvegardés).

## 2. Ce que le cookbook installe

Liste et comptes : `bash $COOKBOOK_DIR/scripts/inventory.sh`.

| Famille | Emplacement |
|---|---|
| Agents (roles génériques + stack) | `.claude/agents/` |
| Skills | `.claude/skills/` |
| Hooks | `.claude/hooks/` |
| Scan sécurité, prod-readiness, SBOM, statusline | `scripts/` |
| Templates (CLAUDE, AGENTS, PRODUCT…) | `docs/templates/` |

**À fournir par chaque projet** (jamais dans le cookbook) : `PRODUCT.md` / `docs/vision.md`, docs domain (architecture, design-system, DB, storage…), agents domain, secrets, `settings.local.json`.

## 3. Compléments recommandés

- **Built-in Claude Code** à connaître : `/init`, `/simplify`, `/code-review`, `/security-review`, `/fewer-permission-prompts`, `/loop`, `/schedule`.
- **`superpowers@claude-plugins-official`** (discipline de session : brainstorming, writing-plans, systematic-debugging, TDD…). **Règle de routage : le skill cookbook, projet-aware, prime sur l'équivalent superpowers générique** (ex : `/feature` plutôt que `brainstorming` + `writing-plans`, `code-reviewer` plutôt que `requesting-code-review`). Ne jamais enchaîner les deux « par sécurité ». Ordre canonique : process amont → expert cookbook → process aval.

## 4. Vérification post-install

| Check | Comment | Attendu |
|---|---|---|
| Agents | `> List the agents available to you` | agents du mode choisi |
| Skills | taper `/` | skills du cookbook listés |
| Deny-rules | `> git commit --no-verify -m x` | refusé par permission deny |
| Hook dispatcher | Edit volontaire d'un pattern P0 de la stack | bloqué avec `[hook:…-P0] BLOCKED` |
| Hook precommit | `git commit` avec diff staged | analyse en stderr + hint `code-reviewer` |
| scan-secu | `bash scan-secu.sh` | étapes auto-comptées, verdict final |

## 5. Troubleshooting

| Symptôme | Cause probable | Fix |
|---|---|---|
| Subagent jamais auto-invoqué | `description` trop vague | verbes actifs + paths précis |
| Hook bloque légitimement | action OK ponctuellement | convention `// canonical-skip:<rule>:<reason>` dans le diff, jamais `--no-verify` |
| `settings.local.json` grossit | accumulation one-shot | skill `fewer-permission-prompts` |
| `product-strategist` rend `BLOCKED-SETUP` | pas de `PRODUCT.md` / `docs/vision.md` | créer une vision minimale (`docs/templates/PRODUCT.md`) |
| Un expert cite un doc absent (`docs/security-multitenant.md`…) | doc domain non fournie | créer le doc projet ou retirer la référence |
