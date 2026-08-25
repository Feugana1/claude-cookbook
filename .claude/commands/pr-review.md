---
description: Review systématique d'une PR existante (own ou reçue). Analyse diff, invoque experts cookbook selon scope, classifie commentaires must/imo/nits/q, poste review via gh.
---

# /pr-review — Review PR systématique

Review une PR existante (`gh pr view <N>`) — soit ta propre PR avant merge, soit une PR d'un collègue. Différent de `code-reviewer` subagent (qui review `git diff --cached` local avant commit) — ici on review une PR déjà pushed avec discussion via GitHub.

## Options

- `--focus security|perf|arch|readability` — biaiser l'audit
- `--post` — poster la review directement via `gh pr review` (sinon dry-run)
- `--approve` / `--request-changes` / `--comment` — action review (défaut `--comment`)

## Méthode

### 1. Charger la PR

```bash
gh pr view <N> --json title,body,files,commits,reviews,checks
gh pr diff <N>
gh pr checks <N>
```

Extraire :
- Titre + description
- Files touchés + stat
- Commits (cohérence intent)
- Reviews existantes (pas doubler)
- CI status (avant/après changements review)

### 2. Détecter le scope

Selon les paths touchés, prévoir experts à invoquer (parallèle) :

| Path modifié | Experts recommandés |
|---|---|
| `app/controllers/**` | `back-architect` + `security-multitenant` + `data-access-reviewer` |
| `app/services/**` | `back-architect` + `security-multitenant` + `data-access-reviewer` + `workflow-email` si scope |
| `app/models/**` | `back-architect` + `data-access-reviewer` |
| `database/migrations/**` | `migration-reviewer` |
| `resources/views/**` | `edge-anti-patterns` + front-architect projet-specific si présent |
| Multi-domain | `code-reviewer` (couche 5) orchestrateur |
| Sécurité IA / LLM | `security` (générique OWASP + LLM) |

Utiliser `/multi-agent <path> <expert1,expert2,...>` pour dispatch parallèle.

### 3. Audit review multi-perspectives

Aligne avec `code-reviewer` cookbook (couche 5) :

**A. Intention** (1 phrase)
- Titre + description matchent le diff ?
- Scope creep ?

**B. Cohérence cross-fichiers**
- Nouvelle entité → tous les artefacts présents (migration + model + validator + controller + view + routes + i18n) ?
- Nouvelle valeur enum TS → `ALTER CONSTRAINT` en migration ?
- Nouvelle route publique → SubdomainMiddleware passthrough OK ?

**C. Discipline projet**
- `docs/features/<name>.md` créé si nouvelle feature ?
- `docs/dev-changelog.md` updated si refactor significatif ?
- Tests présents zones critiques ?
- `product-strategist` verdict cité si nouvelle feature ?

**D. CI status**
- Vert ? Sinon, PR ne mergea pas — flagguer
- Coverage delta OK ?

### 4. Classification commentaires

Convention **must / imo / nits / q** :

| Marqueur | Signification | Priorité |
|---|---|---|
| 🔴 **must** | Bug, sécu, convention violée, breaking | P0 — fix obligatoire |
| 🟡 **imo** | Amélioration structure, refactor | P1 — fix recommandé |
| 🟢 **nits** | Typo, style, indentation | P2 — fix si trivial |
| 🔵 **q** | Question / clarification | Répondre, pas fix code |

### 5. Verdict

- **APPROVE** ✅ : 0 must, ≤ 2 imo mineurs
- **COMMENT** 💬 : 1-3 imo mais pas blocker
- **REQUEST_CHANGES** 🔴 : ≥ 1 must, ou plusieurs imo cumulés, ou CI rouge

### 6. Poster review (si `--post`)

```bash
# Comment multi-line
gh pr review <N> --comment --body "$(cat <<'EOF'
## Review — <verdict>

### 🔴 must
- <file:line> : <problème> — <fix>

### 🟡 imo
- <file:line> : <suggestion>

### 🟢 nits
- <file:line> : <nit>

### 🔵 q
- <file:line> : <question>

### ✅ Positif
- <2-4 mentions concrètes sans flatterie>

Verdict : <APPROVE | COMMENT | REQUEST_CHANGES>
EOF
)"

# Ou approve/request-changes direct
gh pr review <N> --approve --body "LGTM ✅"
gh pr review <N> --request-changes --body "..."
```

## Anti-patterns

- ❌ Approve sans avoir lu diff complet
- ❌ REQUEST_CHANGES sans citer file:line
- ❌ Nits sans must → ne pas request-changes, comment suffit
- ❌ Doublonner review existante d'un autre reviewer
- ❌ Sensibilité au ratio approve/reject artificiel — verdict sur mérite technique

## Format de sortie

```
### PR Review — #<N> · <titre>

**Sources chargées** : gh pr view/diff/checks + docs anti-patterns

**Stats** : <X> fichiers, +<Y>/-<Z> lignes, <N> commits
**CI status** : ✅ green | ❌ fail on <step>
**Reviews existantes** : <count> (résumé)

**Intention détectée** : "<phrase>"
**Scope** : back | front | full-stack | docs | mixed
**Experts invoqués** : <liste via /multi-agent>

---

#### 🔴 must (fix obligatoire)
- `file:line` — <problème> — <fix>

#### 🟡 imo (recommandé)
- ...

#### 🟢 nits
- ...

#### 🔵 q (répondre)
- ...

#### ✅ Positif
- ...

---

**Verdict** : APPROVE ✅ | COMMENT 💬 | REQUEST_CHANGES 🔴

**Action** :
- Dry-run affiché ci-dessus
- `--post` pour poster via `gh pr review`
- Author répond via `/pr-fix` skill
```

## Sources

- Cookbook `code-reviewer` (couche 5) : `.claude/agents/code-reviewer.md`
- Cookbook `/multi-agent` : dispatch parallèle experts
- Cookbook `/pr-fix` : réponse aux comments
- gh CLI : https://cli.github.com/manual/gh_pr_review
