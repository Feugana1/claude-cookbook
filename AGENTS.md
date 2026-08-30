# AGENTS.md — Pour Claude Code

Ce fichier indique aux agents Claude Code comment opérer ce cookbook quand il est invoqué dans un projet utilisateur.

---

## Quand un user te dit "bootstrap ce cookbook" ou "installe la stack Claude"

### Voie A — Plugin natif Claude Code

```
/plugin marketplace add <owner>/claude-cookbook
/plugin install cookbook@claude-cookbook
```

Wire automatique. Confirmer à l'utilisateur :
- Selon mode : 10 agents `roles/` (mode `none` / cross-stack) OU 13 agents (mode `adonisjs` : 6 roles/ conservés + 7 stacks/adonisjs/ durcis, zero redondance)
- 7 skills disponibles (`/feature`, `/pre-pr`, `/secu`, `/ux-review`, `/multi-agent`, `/ai-config`, `/prod-readiness`)
- 13 commands disponibles (`/commit`, `/semantic-commit`, `/pr-create`, `/pr-review`, `/pr-fix`, `/plan`, `/refactor`, `/fix-error`, `/explain-code`, `/analyze-dependencies`, `/analyze-performance`, `/check-fact`, `/tech-debt`)
- 3 hooks wire (dispatch-expert.sh PostToolUse + precommit-check.sh PreToolUse Bash + preserve-file-permissions.sh Pre+PostToolUse)
- `settings.json` chargé (permissions deny + hooks + statusLine)
- `.mcp.json` chargé (Context7 + sequential-thinking + fetch + github)
- `scan-secu.sh` disponible dans `scripts/` (41 étapes tier OWASP)

### Voie B — Bootstrap script

1. **Identifie le projet cible** (cwd ou path explicite)
2. **Détermine la stack cible** — demander à l'user :
   - Projet AdonisJS/Node/TS → `--stack=adonisjs` (13 agents : 6 roles/ + 7 stacks/adonisjs/ durcis)
   - Autre stack ou volonté cross-stack → `--stack=none` (10 roles/ génériques)
3. **Lance** : `bash ~/dev/claude-cookbook/bootstrap-claude.sh <path> --stack=<mode>`
4. **Confirme à l'utilisateur** :
   - Mode `none` : 10 agents installés dans `.claude/agents/roles/`
   - Mode `adonisjs` : 13 agents (6 roles/ conservés + 7 stacks/adonisjs/ durcis, aucune redondance)
   - Liste les 7 skills + 13 commands
   - Indique que `scan-secu.sh` est à la racine, exécutable (41 étapes)
   - Mentionne le `CLAUDE.md` minimal à enrichir
   - Renvoie vers `docs/claude-config/inheritance-map.md` pour le mapping override
4. **Avant d'écrire le 1er commit** : invoque le subagent `product-strategist` pour valider la première feature (couche 0 strategic gate) — **si le projet a une vision produit documentée** (`PRODUCT.md` ou `docs/vision.md`), sinon expliquer qu'il faut d'abord créer une vision.

---

## Quand un user te dit "audite mon repo avec scan-secu"

1. Vérifie présence : `ls scan-secu.sh scan-secu.d/` à la racine
2. Si absent : copier les **deux** (orchestrator + modules step) depuis le cookbook :
   ```
   cp ~/dev/claude-cookbook/scripts/scan-secu.sh .
   cp -r ~/dev/claude-cookbook/scripts/scan-secu.d .
   chmod +x scan-secu.sh
   ```
3. Lance : `bash scan-secu.sh` — TOTAL est auto-compté depuis le nombre de step files
4. Parse l'output tier (T1 BLOCKER / T2 IMPORTANT / T3 ADVISORY) — résume les "Top risks open"
5. Propose fix pour chaque P0 (T1 FAIL) en premier

---

## Architecture du cookbook

Règles :
1. **Un rôle = un fichier**
2. **Générique OU stack, jamais les deux** pour un même use case (bootstrap install exclusif via `--stack=none|adonisjs`)
3. **Stack durcit rôle** — les fichiers `stacks/X/` héritent conceptuellement de leur `roles/Y` équivalent et le durcissent avec les conventions stack

Référence canonique : `docs/claude-config/experts.md` + `docs/claude-config/inheritance-map.md` (mapping override).

**`.claude/agents/roles/`** — 10 rôles génériques opus, 1 fichier par use case :
`analyzer`, `architect`, `backend`, `frontend`, `mobile`, `performance`, `product-strategist`, `qa`, `reviewer`, `security`.

**`.claude/agents/stacks/adonisjs/`** — 7 experts stack-aware (couches 1-5) :

```
Couche 1 — Architect       : back-architect         ← extends roles/architect + roles/backend
Couche 2 — Cross-cutting   : security-multitenant   ← extends roles/security
                             data-access-reviewer (haiku) — pur ajout stack (aucun roles/ équivalent)
                             migration-reviewer            — pur ajout stack
Couche 3 — Domain          : workflow-email                — pur ajout stack
Couche 4 — Linter          : edge-anti-patterns (haiku)    — PAIR avec roles/frontend (linter narrow)
Couche 5 — Final gate      : code-reviewer          ← extends roles/reviewer (avant git commit)
```

**En mode `--stack=adonisjs`** : `roles/architect`, `roles/backend`, `roles/security`, `roles/reviewer` NE sont PAS installés (leur override stack prend le relais). Conservés : `analyzer`, `frontend`, `mobile`, `performance`, `product-strategist`, `qa`.

**Couche 0 strategic gate** : `product-strategist` vit dans `roles/` (générique, conservé dans les 2 modes). Un projet ajoute sa propre stack en créant `.claude/agents/stacks/<nom>/`.

**Règle d'or** : un expert dit "REJECT" → tu corriges, tu ne contournes pas. Pas de complaisance.

---

## Quand un user te dit "ajoute un nouvel agent"

1. Lis `docs/claude-config/experts.md` §7 (Maintenance du catalogue)
2. Vérifie qu'aucun agent existant ne couvre déjà le besoin (anti-duplication)
3. Si nouveau — choisis le dossier selon le scope :
   - **Générique cross-stack** → `.claude/agents/roles/<name>.md`
   - **Stack-specific** → `.claude/agents/stacks/<stack>/<name>.md` (créer le dossier stack si absent)
4. Frontmatter `name/description/tools/model`. Description **active** ("Use PROACTIVELY when…", "Triggers when user says…") — pas "Specialized in…"
5. Ajoute au catalogue dans `docs/claude-config/experts.md`
6. **Si générique (cross-project)** : propose copie vers le cookbook (`cp .claude/agents/roles/<name>.md ~/dev/claude-cookbook/.claude/agents/roles/`)
7. **Si project-specific** : reste local au projet (ex : agent compta NF525, agent marketplace commission, front-architect projet-specific)

---

## Quand un user te dit "applique une lesson learned"

1. Lis `docs/lessons.md` §3 et §4
2. Identifie la lesson pertinente
3. Modifie le code en conséquence
4. **Important** : ajoute le pattern à `docs/anti-patterns.md` si c'est un nouveau pattern découvert
5. **Si générique** : propose update du `docs/anti-patterns.md` du cookbook

---

## Anti-patterns du cookbook lui-même

🚫 **Ne PAS** :
- Réinventer un agent qui existe déjà (utilise `product-strategist` plutôt que créer "vision-validator")
- Ajouter de la cérémonie (semver strict, CHANGELOG.md, releases) — c'est un kit perso solo, pas un produit commercial
- Mélanger code spécifique projet dans les agents génériques (le cookbook doit rester 100% générique — les agents projet-specific vivent dans le `.claude/agents/` du projet)
- Skipper le strategist couche 0 sur new features (CLAUDE.md §8 — règle absolue **si vision produit doc présente**)
- Skipper le code-reviewer couche 5 avant commit (§17.3 — règle absolue)

✅ **Faire** :
- Toujours commencer par `/feature` skill ou `product-strategist` agent (si vision produit doc présente)
- Toujours finir par `/pre-pr` skill ou `code-reviewer` agent
- Garder la discipline §17 Workflow Agentic (plan mode, sous-agents délèguent recherche, vérification avant clôture, boucle auto-amélioration)
- Enrichir `lessons.md` après chaque correction utilisateur

---

## Procédure pour onboarding agent sur projet nouveau

Quand tu démarres un projet **frais** avec ce cookbook :

1. Install cookbook (Voie A plugin OU Voie B bootstrap)
2. Lis le `CLAUDE.md` créé (template ou existant) — c'est ton instruction-set
3. Lis `docs/lessons.md` §1 (Karpathy 4 disciplines)
4. Vérifie `.claude/agents/` — selon mode : 10 agents (mode `none`) OU 13 agents (mode `adonisjs`). Voir `docs/claude-config/inheritance-map.md` pour comprendre les substitutions.
5. **Si le projet a une vision produit** (`PRODUCT.md` OU `docs/vision.md`) : pour la première feature, invoque `product-strategist` avant tout code
6. **Si le projet n'a pas de vision produit** : ne pas invoquer `product-strategist` (il rendra `BLOCKED-SETUP`) — proposer d'abord de créer une vision minimale
7. Après chaque commit non-trivial : invoque `code-reviewer`
8. Avant chaque push : lance `bash scan-secu.sh` + résume top risks

---

## Versioning

Pas de semver strict. Le cookbook évolue par commits granulaires sur son repo dédié. Pour figer une version dans un projet : `bootstrap-claude.sh` copie l'état actuel (pas de "lock file"), ou plugin natif référencé par tag Git. Si tu veux revenir à un état antérieur : `git checkout <sha>` dans le cookbook puis re-bootstrap / re-install plugin.

Le manifest `.claude-plugin/plugin.json` porte une version (`0.2.0` actuellement) mise à jour manuellement sur breaking change.

---

## Pour enrichir le cookbook depuis un projet utilisateur

L'utilisateur travaille typiquement dans un projet. Quand une amélioration générique émerge (nouveau pattern, lesson learned, agent générique) :

1. Implémente localement dans le projet
2. Une fois validé en prod, propose à l'utilisateur : "Cette amélioration est générique, je la copie vers le cookbook ?"
3. Si OK : `cp <fichier-local> ~/dev/claude-cookbook/<même-chemin>`
4. Commit dans le cookbook avec message explicite
5. Les autres projets de l'utilisateur récupèrent via `bootstrap-claude.sh . --update` ou re-install plugin

---

## Mémoire & contexte

Les memories Claude Code (`~/.claude/projects/.../memory/`) restent **par-projet** (pas de partage cross-project). Le cookbook fournit les **patterns**, pas les **observations spécifiques**.

Si un pattern de memory est universel (ex: `feedback_avoid_ceremony.md`), tu peux le copier dans `docs/lessons.md` §4 du cookbook après accord utilisateur.

---

## Discipline non-négociable

Si tu touches à ce cookbook (modify agents, scripts, docs), tu **dois** :
- Garder les agents/hooks/skills **100% génériques** (pas de leak projet-specific dans le cookbook)
- Respecter la limite §14 : controllers ≤300L, services ≤400L, templates ≤800L (sinon split) — appliqué au code d'exemple aussi
- Préserver l'esprit "kit perso solo" (pas de CI release pipeline, pas de multi-lang, pas de cérémonie)
- Valider via `bash scripts/scan-secu.sh` que le scan lui-même reste cohérent
- Grep : `grep -rn "MyProject\|<noms-projet-origine>" .` doit retourner 0 (ou uniquement dans `docs/templates/CLAUDE.md` qui est destiné à être customisé)
