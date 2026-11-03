# AGENTS.md — Instructions opérationnelles Claude Code

> **Destinataire** : Claude Code (l'agent CLI/API/IDE). Ce fichier explique comment opérer sur CE projet spécifique.
> **Différent de CLAUDE.md** : CLAUDE.md = règles + contexte projet (§stack, §naming, §sécurité, §limits). AGENTS.md = playbook opérationnel (quand faire quoi, quel expert invoquer, quel skill lancer).

---

## Stack & mode

- **Stack** : `<remplir : AdonisJS 6 / Next.js 15 / Django 5 / …>`
- **Mode cookbook** : `<--stack=adonisjs | --stack=none>`
- **Agents disponibles** : voir `.claude/agents/` (mode adonisjs → 13 agents / mode none → 10 rôles génériques)

---

## Quand un user te demande "review mon code"

1. **Vérifie diff** : `git diff --cached` (si staged) sinon `git diff`
2. **Match path → expert** :
   - Fichier back → invoquer expert `back-architect` (mode stack) OU `backend` + `architect` (mode none)
   - Sécurité tenant → `security-multitenant` OU `security`
   - Templates UI → `edge-anti-patterns` (Adonis) OU `frontend`
   - Migrations DB → `migration-reviewer`
   - Multi-domain → `code-reviewer` (Adonis) OU `reviewer` (générique)
3. **Multi-agent en parallèle** si scope croise plusieurs experts → `/multi-agent <path> <experts>`
4. **Verdict final** : SHIP / NEEDS CHANGES / REJECT

## Quand un user te demande "audit sécurité"

1. Lance `bash scan-secu.sh --full` (2-3 min, étapes tier OWASP)
2. Parse output tier T1/T2/T3
3. Résume "Top risks open" avec P0 en premier
4. Invoquer `security-multitenant` (Adonis) ou `security` (générique) pour deep-dive P0

## Quand un user te demande "nouvelle feature X"

1. **NE PAS coder immédiatement**. Invoquer `/feature` skill (ou `product-strategist` agent directement)
2. Verdict strategic gate : GO / REVOIR / NO-GO / BLOCKED-SETUP
3. Si GO : suivre workflow §8 CLAUDE.md — spec dans `docs/features/<name>.md` → plan → code → tests → review
4. Si NO-GO : documenter refus, proposer alternative
5. Si BLOCKED-SETUP : PRODUCT.md manquant, aider user à le créer d'abord

## Quand un user te demande "commit"

1. Vérifier diff non-trivial (≥ 2 fichiers OU ≥ 50L OU touche `app/middleware/migrations/routes`)
2. Si non-trivial → invoquer `code-reviewer` (Adonis) ou `reviewer` (générique) AVANT
3. Attendre verdict SHIP
4. Commit format Conventional Commits (voir `commitlint.config.js`)
5. Message via HEREDOC pour préserver formatting

## Quand un user te demande "bootstrap le cookbook"

1. Vérifier stack cible → `--stack=adonisjs` ou `--stack=none`
2. Lancer `bash $COOKBOOK_DIR/bootstrap-claude.sh . --stack=<mode>`
3. Confirmer install : agents count, skills, commands, hooks, scripts, settings

---

## Discipline non-négociable

- **Pas de `git commit --amend`** sauf demande explicite user — préférer nouveaux commits
- **Pas de `--no-verify`** pour skipper hooks — fixer le vrai problème
- **Pas de `git push --force`** sans autorisation explicite
- **Charger sources AVANT analyse** — chaque expert doit lister ses sources avant de conclure
- **Cite `file:line`** dans chaque finding
- **STAY IN SCOPE** — un expert ne commente pas hors de son périmètre

---

## Extension projet-specific

Si ce projet a des experts domain custom (ex : `nf525-accounting`, `shop-marketplace`, `<votre-domain>`), les documenter ici avec leur trigger :

| Expert | Path | Trigger |
|---|---|---|
| `<expert-name>` | `.claude/agents/<expert>.md` | Editing files in `<pattern>` |

Ajouter aussi les hints dispatch dans `.claude/hooks/dispatch-expert.local.sh` (sourcé automatiquement).

---

## Références

- Cookbook `docs/claude-config/experts.md` — catalogue complet agents
- Cookbook `docs/claude-config/stack-adonisjs.md` — mapping roles ↔ stacks
- CLAUDE.md — règles projet (stack, naming, conventions, limits)
- PRODUCT.md — vision produit (utilisée par `product-strategist`)
