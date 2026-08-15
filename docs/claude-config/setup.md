# Claude Code — setup cross-poste

> Procédure pour reproduire l'environnement Claude Code MyProject sur une nouvelle machine.
> Source : [`README.md`](README.md) + [`experts.md`](experts.md) + [`skills.md`](skills.md).

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

## 1. Cloner le repo

```bash
git clone https://github.com/<your-github>/<your-project>.git
cd myproject-repo
npm ci
cp .env.example .env
node ace generate:key  # remplir APP_KEY dans .env
# (renseigner DB, Redis, S3, NotchPay, Stripe selon .env.example)
```

---

## 2. Claude Code — login

```bash
claude login
# crée ~/.claude/.credentials.json (token API, JAMAIS commit)
```

---

## 3. Configuration projet (`.claude/` dans le repo)

**Post-R01** (whitelist `.gitignore`) — tout est déjà dans le repo et sera cloné :

```
.claude/
├── agents/           ← 9 subagents experts (cf experts.md §4.1)
├── skills/           ← skills projet (ux-review + autres)
├── commands/         ← slash commands custom
├── hooks/            ← scripts hooks (dispatch-expert.sh, etc.)
└── settings.json     ← settings projet partagé (permissions équipe + hooks)
```

**Avant R01** (état actuel) — `.claude/` est entièrement gitignored : à initialiser à la main depuis le snapshot :

```bash
# 1. Récupérer les skills depuis snapshot
ls docs/claude-config/snapshot/ 2>/dev/null || echo "snapshot pas encore créé"

# 2. Réinstaller les skills externes (cf skills.md pour la liste)
# 3. Créer settings.local.json vide
mkdir -p .claude
echo '{"permissions":{"allow":[]}}' > .claude/settings.local.json
```

Une fois R01 livré, cette section disparaît — `git clone` suffit.

---

## 4. Configuration user (`~/.claude/`)

Ces fichiers sont **propres à chaque machine** et ne sont jamais commités dans le projet. Mais leur **structure de référence** est dans le repo :

### 4.1 `~/.claude/settings.json`

Copier le snapshot sanitized :

```bash
# Backup si existe déjà
cp ~/.claude/settings.json ~/.claude/settings.json.bak 2>/dev/null || true

# Restaurer
cp docs/claude-config/settings/user-settings.json ~/.claude/settings.json
```

> Les paths bash dans `permissions.allow` ont été sanitized en `<PROJECT_ROOT>` dans le snapshot. Claude les régénère au premier usage avec le path réel.

### 4.2 `~/.claude/CLAUDE.md` (préférences cross-projet, R10)

Si présent dans snapshot :

```bash
cp docs/claude-config/user-claude-md.template ~/.claude/CLAUDE.md
```

Sinon, créer manuellement avec ses préférences (langue, style commit, niveau verbosité). Cf [`experts.md` §9 R10](experts.md#9-roadmap--état-dimplémentation) pour le contenu recommandé.

### 4.3 Plugins marketplace

```bash
# Lister les plugins du snapshot
cat docs/claude-config/settings/installed-plugins.json

# Réinstaller chacun (manuel, pas d'import auto Claude Code)
/plugin install <plugin-name>@<plugin-source>
```

Plugins actifs actuellement (snapshot 2026-05-30) :
- `caveman@caveman` — communication ultra-compressée

---

## 5. Vérification post-install

### 5.1 CLAUDE.md projet chargé

```bash
# Lancer une session Claude depuis le repo
claude
# Dans la session, taper :
> Quelle est la règle §17.6 ?
# Doit citer "UI density gate (>4 sections = STOP)"
```

### 5.2 Subagents listés (12 attendus)

```bash
# Dans une session Claude :
> List the agents available to you
```

Doit lister les 12 subagents en 6 couches :

| Couche | Agent | Model |
|---|---|---|
| 0 Strategic | `product-strategist` | sonnet |
| 1 Architects | `front-curator`, `back-architect` | sonnet |
| 2 Cross-cutting | `security-multitenant`, `data-access-reviewer`, `migration-reviewer` | sonnet/haiku |
| 3 Domain | `nf525-accounting`, `shop-marketplace`, `workflow-email`, `public-experience` | sonnet |
| 4 Linters | `edge-anti-patterns` | haiku |
| 5 Final gate | `code-reviewer` | sonnet |

### 5.3 Skills listés (4 attendus)

```bash
# Dans une session Claude, taper /
```

Doit lister `/feature`, `/ux-review`, `/secu`, `/pre-pr` parmi les skills built-in.

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
# Dans une session, après avoir staged un diff non-trivial (≥ 2 fichiers ou ≥ 50 lignes) :
> git commit -m "test"
# Doit afficher en stderr :
# "[hook:precommit] Staged paths analysis : ts=... app|views=..."
# "[hook:precommit] Running typecheck…"  (si .ts staged)
# "[hook:precommit] Hint: invoke 'code-reviewer' subagent for senior PR review..."
```

### 5.6 Permissions deny actives

```bash
# Dans une session :
> git commit --no-verify -m "test"
# Doit être REFUSÉ : permission deny "Bash(git commit *--no-verify*)"
```

### 5.7 scan-secu.sh fonctionnel

```bash
bash scan-secu.sh
# Doit dérouler les 24 étapes, terminer par "READY TO PUSH" ou "BLOCKED"
```

### 5.8 Skills opérationnels

```bash
# Dans une session Claude :
> /ux-review pages/portfolio
# Doit charger ux-audit-prompt.md et auditer le portfolio

> /feature gallery-music-spotify
# Doit invoquer product-strategist, charger competitive-benchmark/*,
# poser les 7 questions canoniques, rendre verdict GO/REVOIR/NO-GO

> /secu
# Doit lancer bash scan-secu.sh et résumer FAIL/WARN avec fix proposé

> /pre-pr
# Doit séquencer lint → typecheck → build → ratchet
```

### 5.9 Référentiel concurrents accessible

```bash
ls docs/competitive-benchmark/
# Doit lister : README.md + _template.md + 13 fichiers concurrents
# (honeybook.md, pic-time.md, pixieset.md, tave.md, studio-ninja.md,
#  17hats.md, iris-works.md, shootproof.md, sprout-studio.md,
#  cloudspot.md, unscripted.md, picflow.md, pelli.md)
```

---

## 6. Synchronisation snapshot (quand la conf locale évolue)

À refaire après ajout d'un plugin, modification de `~/.claude/settings.json`, ou installation d'un skill externe :

```bash
# 1. Settings user (sanitize les paths)
sed 's|/Users/[^/]*/Documents/dev/myproject-repo|<PROJECT_ROOT>|g' \
   ~/.claude/settings.json > docs/claude-config/settings/user-settings.json

# 2. Plugins
cp ~/.claude/plugins/installed_plugins.json \
   docs/claude-config/settings/installed-plugins.json 2>/dev/null || \
   echo '{}' > docs/claude-config/settings/installed-plugins.json

# 3. Commit
git add docs/claude-config && \
git commit -m "chore(claude-config): refresh snapshot $(date +%Y-%m-%d)"
```

Pas de snapshot nécessaire pour les évolutions **projet** (`.claude/agents/`, `.claude/skills/`, `.claude/hooks/`, `.claude/settings.json`) — elles sont versionnées directement dans le repo après R01.

---

## 7. Troubleshooting

| Symptôme | Cause probable | Fix |
|---|---|---|
| Subagent listé mais jamais auto-invoqué | Description-trigger trop vague | Renforcer le `description` frontmatter avec patterns paths précis + verbes "Use PROACTIVELY when…" |
| Hook bloque légitimement mais on veut bypass | Action OK ponctuellement | `// canonical-skip:<rule>:<reason>` dans le diff (convention scan-secu.sh §22) — pas `--no-verify` |
| Skill `/ux-review` introuvable | `.claude/skills/` pas encore versionné (avant R01) ou non installé | `ls .claude/skills/ux-review/SKILL.md` — si manquant, copier depuis snapshot ou recréer |
| `~/.claude/settings.json` perdu | Réinstall OS | Étape 4.1 — restaurer depuis snapshot |
| Permissions explosées (`settings.local.json` grossit) | Accumulation one-shot perl/sed | Lancer skill built-in `fewer-permission-prompts` pour audit + nettoyage |
| `claude login` refuse | Token expiré | Re-`claude login` |

---

## 8. État de l'implémentation

Cette procédure suppose **R01 livré** (cf [`experts.md` §9](experts.md#9-roadmap--état-dimplémentation)). Tant que R01 n'est pas validé :
- `.claude/agents/`, `.claude/skills/`, `.claude/hooks/`, `.claude/settings.json` **ne sont PAS versionnés**
- L'étape **§3 (Configuration projet)** se réduit à : créer un `.claude/settings.local.json` vide
- L'étape **§5 (Vérification)** : seuls les built-in skills répondent

Après R01 → R04c (bloc P0 implémenté), la procédure complète est opérationnelle.
