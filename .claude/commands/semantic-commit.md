---
description: Split un gros diff en N commits sémantiques cohérents (Conventional Commits). Groupe fichiers par intent (feat/fix/refactor/docs), propose message par groupe, commit séquentiellement. Complémentaire `/commit` (un commit unique).
---

# /semantic-commit — Split diff en N commits sémantiques

Utilise quand le diff est trop gros pour un seul commit propre (≥ 5 fichiers OU ≥ 100 lignes OU intent mixte : feat + fix + refactor).

## Options

- `--dry-run` — affiche split proposé sans commit
- `--max-commits <N>` — cap (défaut 10)
- `--lang <fr|en>` — langue message commit (défaut détection projet)

## Méthode

### 1. Analyser le scope

```bash
git status --short
git diff HEAD --stat
git diff HEAD --name-only
```

Compter fichiers + lignes. Trigger split si :
- ≥ 5 fichiers
- ≥ 100 lignes changées
- Détecte intent mixte (feat + fix ensemble)

### 2. Grouper par intent

Grouper les fichiers par domaine + intent :

| Signal | Type |
|---|---|
| Nouveau fichier + tests + doc → même feature | `feat(scope)` |
| Modif ciblée corrective sur code existant | `fix(scope)` |
| Restructuration sans changement comportement | `refactor(scope)` |
| Modif `docs/`, `README.md`, `*.md` seul | `docs(scope)` |
| Modif `test/`, `__tests__/`, `*.test.ts` seul | `test(scope)` |
| Modif `.github/`, `Dockerfile`, `*.yml` CI/deploy | `ci(scope)` OU `build(scope)` |
| Modif `package.json`, deps files | `chore(deps)` |
| Formatting seul | `style(scope)` |

Détection intent :
- Grep patterns dans le diff (ajout fonction publique = feat, modif signature = refactor breaking, if/else ajouté = fix probable)
- Corrélation temporelle avec `git log` récent (branche `feat-*` → probable feat)

### 3. Proposer split

Afficher plan (dry-run) :

```
### Semantic-commit — split proposé

**Diff analysé** : <N> fichiers, +<X>/-<Y> lignes
**Split proposé** : <M> commits

**Commit 1/M** — `type(scope): sujet ≤ 50 chars`
Files (<count>):
- <file1>
- <file2>

**Commit 2/M** — `type(scope): sujet`
Files (<count>):
- <file3>

...
```

### 4. Confirmation user

- User approve → exécuter séquentiellement
- User propose modifs → ajuster + re-afficher
- User refuse → abort

### 5. Commit séquentiel

Pour chaque commit :

```bash
# Reset index
git reset HEAD

# Stage seulement les files du groupe
git add <file1> <file2> ...

# Commit HEREDOC
git commit -m "$(cat <<'EOF'
type(scope): sujet

Body si nécessaire (why, pas quoi).

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

Si `code-reviewer` requis (diff cumulé du groupe ≥ 50L) → invoquer AVANT commit du groupe.

### 6. Vérifier

```bash
git log --oneline -${M}
git status  # doit être clean
```

## Ordre commits

Convention : dépendances d'abord.

1. `chore(deps)` — nouvelles deps
2. `feat` / `refactor` — code principal
3. `test` — tests associés
4. `docs` — doc mise à jour
5. `ci` / `build` — pipeline last

## Anti-patterns

- ❌ Split arbitraire (1 commit par fichier) — grouper par intent
- ❌ Commit "feat + fix" mixte — refuser, split obligatoire
- ❌ `--amend` pour "corriger" split raté — reset + refaire propre
- ❌ Skip confirmation user → surprise

## Format de sortie

```
### Semantic-commit — plan

**Scope initial** : <N> fichiers, +<X>/-<Y> lignes
**Trigger split** : ✅ (≥5 files / ≥100L / intent mixte)

**Split proposé** : <M> commits séquentiels

[Commit 1/M] type(scope): sujet ≤ 50 chars
  Files: <liste>
  Intent: feat | fix | refactor | docs | test | ci | chore

[Commit 2/M] ...

**Ordre exécution** : deps → code → tests → docs → ci

**Action** :
- Confirmer avant exécution
- Chaque commit sera fait séparément, hook precommit auto
- Si `code-reviewer` requis sur un groupe : invoqué avant
```

## Sources

- Conventional Commits : https://www.conventionalcommits.org
- Cookbook `/commit` : `.claude/commands/commit.md` (un commit unique)
- Cookbook `code-reviewer` : couche 5 (invoqué si groupe ≥ 50L)
