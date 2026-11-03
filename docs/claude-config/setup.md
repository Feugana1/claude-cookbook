# Claude Code — setup cross-poste (cookbook)

> Procédure pour installer le cookbook Claude Code sur une nouvelle machine ou un nouveau projet.

---

## 0. Pré-requis machine

| Outil | Version min | Vérif |
|---|---|---|
| Node.js | 20+ | `node -v` |
| npm | 10+ | `npm -v` |
| git | 2.40+ | `git --version` |
| Claude Code CLI | dernière | `claude --version` (install : https://docs.claude.com/claude-code) |
| `jq` | 1.6+ | `jq --version` (utilisé par hooks) |
| `bash` | 4+ ou zsh | (macOS shipped) |

Optionnels (pour `scan-secu.sh` complet) : `trivy`, `gitleaks`, `jscpd`, `license-checker`. Le script skip gracieusement si absent.

---

## 1. Installation du cookbook

### Voie A — Plugin natif Claude Code (recommandé)

```bash
# Depuis n'importe quel dossier ou projet :
/plugin marketplace add <owner>/claude-cookbook
/plugin install cookbook@claude-cookbook
```

Le plugin déploie automatiquement : agents, skills, hooks, settings (permissions + wire hooks), MCP config (P1).

### Voie B — Bootstrap script (fallback)

```bash
# 1. Cloner le cookbook
export COOKBOOK_DIR=<chemin-du-clone>   # là où tu clones le cookbook
git clone <cookbook-repo> "$COOKBOOK_DIR"

# 2. Depuis le dossier de ton projet — choisir la stack (exclusif)
cd <mon-projet>
bash $COOKBOOK_DIR/bootstrap-claude.sh . --stack=adonisjs   # projet AdonisJS/Node/TS
# ou
bash $COOKBOOK_DIR/bootstrap-claude.sh . --stack=none       # cross-stack universel
```

Sans `--stack` en TTY : le script propose un menu interactif. En CI non-TTY : défaut `none`.

Le script copie `.claude/`, `scripts/`, `docs/`, `settings.json` dans le projet cible + crée `CLAUDE.md` minimal à enrichir. Mapping override roles ↔ stacks : [`inheritance-map.md`](inheritance-map.md).

Mode update : `bash $COOKBOOK_DIR/bootstrap-claude.sh . --update` (préserve les fichiers spécifiques projet).

---

## 2. Claude Code — login

```bash
claude login
# crée ~/.claude/.credentials.json (token API, JAMAIS commit)
```

---

## 3. Configuration projet installée par le cookbook

Après install (Voie A ou B) :

```
.claude/
├── agents/                       ← install exclusif selon --stack=none|adonisjs
│   ├── roles/                    ← mode `none` : 10 rôles / mode `adonisjs` : 6 rôles conservés
│   │                                (analyzer, frontend, mobile, performance,
│   │                                product-strategist, qa)
│   └── stacks/adonisjs/          ← mode `adonisjs` : 7 experts stack-aware (couches 1-5)
│                                    dont 3 override roles/ (back-architect, code-reviewer,
│                                    security-multitenant) + 4 purs ajouts (data-access-reviewer,
│                                    edge-anti-patterns, migration-reviewer, workflow-email)
├── skills/                       ← /feature /ux-review /secu /pre-pr /multi-agent
└── hooks/                        ← dispatch-expert.sh + precommit-check.sh

settings.json         ← permissions deny + hooks wire (racine cookbook, sourcé au load)
scripts/              ← scan-secu.sh + 41 étapes + check-file-sizes.js + generate-sbom.sh
docs/                 ← lessons.md + anti-patterns.md + feature-plan-template.md + ux-audit-prompt.md + claude-config/
```

Extension projet-specific (à ajouter localement, non versionnés dans cookbook) :
- Agents domain (`nf525-accounting`, `shop-marketplace`, `workflow-email` custom, `public-experience`, etc.)
- Docs domain (`docs/architecture.md`, `docs/design-system.md`, `docs/database-neon.md`, `docs/storage-s3.md`, `docs/security-multitenant.md`)
- Vision produit (`PRODUCT.md`, `docs/vision.md`, `docs/competitive-benchmark/*.md`, `docs/roadmap.md`)
- Hook extension `.claude/hooks/dispatch-expert.local.sh` (sourcé si présent — pour hints domain-specific)

---

## 4. Configuration user (`~/.claude/`)

Ces fichiers sont **propres à chaque machine** et ne sont jamais commités dans le projet.

### 4.1 `~/.claude/settings.json`

Préférences user cross-projet (verbosité, modèle par défaut, etc.). Optionnel — chaque user tient le sien.

### 4.2 `~/.claude/CLAUDE.md`

Préférences user cross-projet (langue, style commit, niveau verbosité). Optionnel.

### 4.3 Plugins marketplace

```bash
# Lister les plugins installés
/plugin list

# Recommandés en complément du cookbook :
# - superpowers@claude-plugins-official (skills discipline session — brainstorming, writing-plans, systematic-debugging, etc.)
```

Le cookbook référence `superpowers` pour la discipline de session — cf [`superpowers-integration.md`](superpowers-integration.md).

---

## 5. Vérification post-install

### 5.1 CLAUDE.md projet chargé (si projet a un CLAUDE.md)

```bash
claude
# Dans la session :
> Quelle est la règle §14 ?
# Doit citer les limites de taille (controllers 300, services 400, templates 800)
```

### 5.2 Subagents listés

```bash
> List the agents available to you
```

Doit lister les **17 subagents cookbook** :

**Stack AdonisJS (7 experts en 5 couches)** — `.claude/agents/stacks/adonisjs/` :

| Couche | Agent | Model |
|---|---|---|
| 1 Architect | `back-architect` | sonnet |
| 2 Cross-cutting | `security-multitenant`, `data-access-reviewer`, `migration-reviewer` | sonnet/haiku |
| 3 Domain | `workflow-email` | sonnet |
| 4 Linter | `edge-anti-patterns` | haiku |
| 5 Final gate | `code-reviewer` | sonnet |

**Rôles génériques opus (10 personas cross-stack)** — `.claude/agents/roles/` :

| Agent | Rôle |
|---|---|
| `analyzer` | Root cause 5 Whys |
| `architect` | Conception Evidence-First + MECE |
| `backend` | API RESTful/GraphQL, microservices |
| `frontend` | WCAG 2.1, Core Web Vitals |
| `mobile` | iOS HIG + Android Material |
| `performance` | Profilage + optim ROI-driven |
| `product-strategist` | Strategic gate différenciation feature (couche 0) |
| `qa` | Test pyramid + coverage |
| `reviewer` | Générique code review (hors stack) |
| `security` | OWASP Top 10 + OWASP LLM |

Si le projet a ajouté des agents projet-specific, ils apparaissent en plus.

### 5.3 Skills listés

```bash
# Dans une session Claude, taper /
```

Doit lister `/feature`, `/ux-review`, `/secu`, `/pre-pr` parmi les skills disponibles.

### 5.4 Hook dispatcher actif (PostToolUse Edit/Write)

```bash
# Dans une session Claude, demander un edit P0 volontaire :
> Edit app/services/test_dispatcher.ts pour ajouter `auth.user.id` quelque part
# Doit être BLOQUÉ par le hook avec message :
# "[hook:sec-P0] BLOCKED — 'auth.user.id' dans app/services/test_dispatcher.ts —
# utiliser 'effectiveUserId' (middleware team). Invoke 'security-multitenant' subagent."
```

### 5.5 Hook precommit actif (PreToolUse Bash)

```bash
# Après avoir staged un diff non-trivial :
> git commit -m "test"
# Doit afficher en stderr :
# "[hook:precommit] Staged paths analysis : ts=... app|views=..."
# "[hook:precommit] Running typecheck…"  (si .ts staged)
# "[hook:precommit] Hint: invoke 'code-reviewer' subagent for senior PR review..."
```

### 5.6 Permissions deny actives

```bash
> git commit --no-verify -m "test"
# Doit être REFUSÉ : permission deny "Bash(git commit *--no-verify*)"
```

### 5.7 scan-secu.sh fonctionnel

```bash
bash scan-secu.sh
# Doit dérouler les 41 étapes (nombre auto-compté depuis scan-secu.d/),
# terminer par "READY TO PUSH" / "BLOCKED" / "NEEDS REVIEW" / "SHIP WITH DEBT"
```

### 5.8 Skills opérationnels

```bash
> /ux-review pages/<un-écran>
# Doit charger ux-audit-prompt.md et auditer

> /feature <nouvelle-idée>
# Doit invoquer brainstorming + product-strategist (si sources produit projet présentes)

> /secu
# Doit lancer bash scan-secu.sh et résumer FAIL/WARN avec fix proposé

> /pre-pr
# Doit séquencer lint → typecheck → build → ratchet
```

---

## 6. Troubleshooting

| Symptôme | Cause probable | Fix |
|---|---|---|
| Subagent listé mais jamais auto-invoqué | Description-trigger trop vague | Renforcer le `description` frontmatter avec patterns paths précis + verbes "Use PROACTIVELY when…" |
| Hook bloque légitimement mais on veut bypass | Action OK ponctuellement | `// canonical-skip:<rule>:<reason>` dans le diff (convention scan-secu.sh §22) — pas `--no-verify` |
| Skill `/ux-review` introuvable | `.claude/skills/` pas installé | Voir §1 install ou vérifier `ls .claude/skills/ux-review/SKILL.md` |
| Permissions explosées (`settings.local.json` grossit) | Accumulation one-shot perl/sed | Lancer skill built-in `fewer-permission-prompts` pour audit + nettoyage |
| `claude login` refuse | Token expiré | Re-`claude login` |
| `product-strategist` renvoie `BLOCKED-SETUP` | Le projet n'a pas de `PRODUCT.md` ou de `docs/vision.md` | Créer une vision produit minimale avant d'invoquer le skill `/feature` |
| `code-reviewer` ne trouve pas `docs/security-multitenant.md` | Doc non versionnée dans le projet | Créer les docs domain projet-specific référencées par les experts (voir README §"Ce que le cookbook n'installe pas") |
