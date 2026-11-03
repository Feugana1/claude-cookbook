---
name: commit
description: Create Conventional Commits from staged changes - one commit, or --split to cut a large mixed diff into several semantic commits. Reviews non-trivial diffs first, never uses --no-verify or amend.
disable-model-invocation: true
argument-hint: "[--split] [--dry-run] [--max-commits N]"
allowed-tools: Bash(git status:*) Bash(git diff:*) Bash(git log:*) Bash(git add:*) Bash(git reset:*) Bash(git commit:*) Read Grep Agent
---

# /commit — commit discipliné (Conventional Commits)

Un commit propre sur `git diff --cached`, ou plusieurs avec `--split`.

## Règles

- **Jamais `--no-verify`**, **jamais `--amend`** : nouveau commit toujours. Si un hook bloque, corriger, re-stager, nouveau commit.
- Format `type(scope): sujet` impératif, ≤ 50 caractères, sans point final.
- Body uniquement si le **pourquoi** n'est pas évident (le diff montre le quoi).
- Terminer par la ligne `Co-Authored-By` prescrite par les instructions de la session, si elle existe.
- Diff non trivial (≥ 2 fichiers, ≥ 50 lignes, ou migrations/routes/middleware) : **review avant commit** par le reviewer final du projet (`code-reviewer` si le pack de stack est installé, sinon `reviewer`). Attendre un verdict SHIP.

## Types

`feat` (feature user-facing) · `fix` · `refactor` (sans changement de comportement) · `perf` · `docs` · `test` · `chore` (deps, config) · `style` (formatage) · `ci` · `build`.

## Mode simple

1. `git diff --cached --stat` et `--name-only`. Classer : trivial (< 2 fichiers, < 50 L) / standard / substantial (> 10 fichiers ou > 300 L).
2. Substantial ou intent mixte (feat + fix + refactor) : proposer `--split`.
3. Non trivial : lancer la review, attendre SHIP.
4. Lire le diff, formuler l'intention (1 phrase) et le pourquoi si besoin.
5. Proposer le message, **confirmer avec l'utilisateur**, puis commiter avec un HEREDOC :

```bash
git commit -m "$(cat <<'MSG'
type(scope): sujet

Body si nécessaire.
MSG
)"
```

6. `git status` après le commit.

## Mode `--split`

Pour un diff trop gros ou mixte (≥ 5 fichiers, ≥ 100 lignes, ou intent mixte). Options : `--dry-run` (affiche le plan sans commiter), `--max-commits N` (défaut 10).

1. `git status --short` et `git diff HEAD --stat`.
2. **Grouper par intent**, pas un commit par fichier :

| Signal | Type |
|---|---|
| nouveau code + ses tests + sa doc | `feat(scope)` |
| correction ciblée de code existant | `fix(scope)` |
| restructuration sans changement de comportement | `refactor(scope)` |
| `docs/`, `*.md` seuls | `docs` |
| fichiers de test seuls | `test` |
| CI, Dockerfile, pipeline | `ci` / `build` |
| fichiers de dépendances | `chore(deps)` |
| formatage seul | `style` |

3. **Ordre** : deps → code (feat/refactor) → tests → docs → ci/build.
4. Afficher le plan (`[1/M] type(scope): sujet` + fichiers), **attendre la confirmation**, ajuster si demandé. `--dry-run` s'arrête ici.
5. Pour chaque groupe : `git reset HEAD`, `git add <fichiers du groupe>`, review si le groupe fait ≥ 50 lignes, commit en HEREDOC.
6. `git log --oneline -<M>` et `git status` : l'arbre doit être propre.

## Refusé

- ❌ Titre vague (« update », « wip », « fixes »)
- ❌ Body qui répète le diff
- ❌ Un commit qui mélange feat + fix + refactor : splitter
- ❌ `--amend` pour « réparer » un split raté : reset et refaire proprement
- ❌ Commiter sans confirmation de l'utilisateur
- ❌ Commit non trivial sans review

## Format de sortie

```
### Commit — proposé
**Scope** : trivial | standard | substantial — <N> fichiers, +X/-Y
**Review** : skip (trivial) | <agent> → SHIP | NEEDS CHANGES | REJECT
**Message** :
type(scope): sujet

[--split] [1/M] type(scope): sujet — fichiers : …
**Action** : confirmer avant exécution
```
