---
description: Crée une PR draft avec description auto-générée depuis git log/diff. Utilise PULL_REQUEST_TEMPLATE.md si présent. Auto-select labels (max 3). Précédé par /pre-pr.
---

# /pr-create — Créer une PR draft

Crée une PR draft depuis la branche courante. Auto-génère titre + description depuis git log + diff. Utilise `.github/PULL_REQUEST_TEMPLATE.md` si présent.

## Pré-requis

1. **`/pre-pr` OK** : lint + typecheck + build + file-size ratchet — cf `.claude/skills/pre-pr/SKILL.md`
2. Branche pushed sur remote (`git push -u origin <branch>` si première fois)
3. `gh` CLI authentifié (`gh auth status`)

Si `/pre-pr` fail → refuser création PR, indiquer le fix.

## Méthode

### 1. Vérifier état branche

```bash
git status                             # working tree clean ?
git branch --show-current              # sur bonne branche ?
git log main..HEAD --oneline           # commits divergents
git diff main...HEAD --stat            # diff cumulé vs base
git ls-remote --heads origin <branch>  # branche présente sur remote ?
```

Si branche non-pushed : `git push -u origin <branch>` d'abord.

### 2. Détecter le template

```bash
if [ -f .github/PULL_REQUEST_TEMPLATE.md ]; then
  cp .github/PULL_REQUEST_TEMPLATE.md /tmp/pr_body.md
else
  # fallback template minimal
  cat > /tmp/pr_body.md <<'EOF'
## Summary

<1-3 bullets>

## Test plan

- [ ] <checklist testing>
EOF
fi
```

**Règle** : préserver **tout le contenu existant** du template (HTML comments, séparateurs `---`, sections vides). Remplir uniquement les zones vides.

### 3. Analyser diff pour titre + description

```bash
# Commits messages
git log main..HEAD --format="%s%n%b" > /tmp/pr_commits.txt

# Files changed
git diff main...HEAD --name-only > /tmp/pr_files.txt

# Diff stat
git diff main...HEAD --shortstat
```

- **Titre PR** : type commit dominant + résumé — max 70 chars
- **Description** : bullets par domaine (Summary/Test plan/Notes)
- **Ne PAS répéter le diff** — décrire intention + risques

### 4. Auto-select labels (max 3)

Depuis `.github/labels.yml` OU `gh label list`. Correspondance :

| Motif | Label |
|---|---|
| `*.md`, `docs/` | `documentation`, `docs` |
| `test`, `spec` | `test` |
| `.github/`, `*.yml`, `Dockerfile` | `ci`, `build` |
| `package.json`, deps files | `dependencies` |
| commit `fix\|bug\|error` | `bug` |
| commit `feat\|add` | `feature`, `enhancement` |
| commit `refactor\|clean` | `refactor` |
| commit `perf\|optimize` | `performance` |
| commit `security` | `security` |

**Contrainte** : que des labels existants — ne pas créer.

### 5. Créer PR draft

```bash
gh pr create \
  --draft \
  --base main \
  --head "$(git branch --show-current)" \
  --title "type(scope): sujet" \
  --body "$(cat /tmp/pr_body.md)" \
  --label "label1,label2"
```

**Draft toujours** — passer en Ready via `gh pr ready` après CI verte.

### 6. Vérifier

```bash
gh pr view --json url,title,labels,isDraft
```

## Anti-patterns

- ❌ Créer une PR sans avoir passé `/pre-pr`
- ❌ Force push après création PR (perturbe review)
- ❌ Créer des labels nouveaux à la volée
- ❌ Ready-for-review immédiat sans attendre CI
- ❌ Supprimer les HTML comments du template
- ❌ Push --force sur PR déjà en review (utiliser force-with-lease si vraiment nécessaire, permission deny active sur `--force`)

## Format de sortie

```
### PR create — état

**Branche** : <branch>
**Base** : main
**Divergence** : <N> commits, +<X>/-<Y> lignes
**Pre-PR** : ✅ passé | ❌ échec sur <step>

**Titre proposé** : <title ≤ 70 chars>
**Labels auto-select** : <label1,label2,...>
**Template** : .github/PULL_REQUEST_TEMPLATE.md | fallback minimal

**Body proposé** (preview) :
---
<contenu markdown>
---

**Action** :
- Confirmer avant `gh pr create`
- PR sera créée en **DRAFT** — passer en Ready via `gh pr ready` après CI verte
```

## Sources

- Cookbook `/pre-pr` : `.claude/skills/pre-pr/SKILL.md`
- Cookbook `/commit` : `.claude/commands/commit.md`
- gh CLI : https://cli.github.com/manual/gh_pr_create
