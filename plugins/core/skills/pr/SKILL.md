---
name: pr
description: Pull request workflow with gh - create a draft PR from the branch, review an existing PR with must/imo/nits/q classification, or fix review comments with new commits. Modes create, review, fix.
disable-model-invocation: true
argument-hint: "<create|review|fix> [PR number] [--post] [--focus security|perf|arch|readability] [--approve|--request-changes|--comment]"
allowed-tools: Bash(gh pr:*) Bash(gh label:*) Bash(gh auth status) Bash(git status:*) Bash(git diff:*) Bash(git log:*) Bash(git branch:*) Bash(git ls-remote:*) Bash(git push:*) Bash(git add:*) Bash(git commit:*) Read Grep Glob Agent
---

# /pr — workflow de pull request

Trois modes : `create`, `review`, `fix`. Prérequis : `gh` authentifié (`gh auth status`). Toute action visible par d'autres (créer, poster une review, pousser) se fait **après confirmation** de l'utilisateur.

## Taxonomie commune des commentaires

| Marqueur | Sens | Priorité |
|---|---|---|
| 🔴 **must** | bug, sécurité, convention violée, breaking | P0 — fix obligatoire |
| 🟡 **imo** | amélioration de structure, refactor | P1 — recommandé |
| 🟢 **nits** | typo, style, naming mineur | P2 — si trivial |
| 🔵 **q** | question | répondre, pas de code |

## Mode `create` — PR en draft

1. **Prérequis** : lancer `/pre-pr` ; s'il échoue, refuser la création et indiquer le fix. Branche poussée (`git push -u origin <branche>` si première fois).
2. **État** : `git status` (arbre propre), `git log <base>..HEAD --oneline`, `git diff <base>...HEAD --stat`. La base est la branche par défaut du dépôt (`gh repo view --json defaultBranchRef`).
3. **Template** : utiliser `.github/PULL_REQUEST_TEMPLATE.md` s'il existe, en préservant **tout** son contenu (commentaires HTML, séparateurs) et en ne remplissant que les zones vides. Sinon : `## Summary` (1-3 puces) et `## Test plan` (checklist).
4. **Titre** (≤ 70 caractères) : type dominant des commits + résumé. **Description** : intention et risques, sans répéter le diff.
5. **Labels** (max 3, **existants seulement**, via `gh label list`) : docs → `documentation`, tests → `test`, CI → `ci`, dépendances → `dependencies`, commits `fix` → `bug`, `feat` → `feature`, etc. Ne jamais en créer.
6. Après confirmation : `gh pr create --draft --base <base> --title "<titre>" --body "$(cat <<'BODY' … BODY)" --label "<l1,l2>"`. **Toujours draft** ; `gh pr ready` après CI verte.
7. `gh pr view --json url,title,labels,isDraft`.

## Mode `review` — relire une PR existante (la sienne ou une reçue)

Distinct de la review locale d'avant commit (`code-reviewer` / `reviewer` sur `git diff --cached`) : ici la PR est déjà poussée et discutée.

1. **Charger** : `gh pr view <N> --json title,body,files,commits,reviews,checks`, `gh pr diff <N>`, `gh pr checks <N>`. Ne pas doublonner les reviews existantes.
2. **Choisir les experts** par correspondance entre les chemins touchés et les `description` des agents installés (ou `docs/dispatch-matrix.md` si présent), puis dispatcher en parallèle avec `/multi-agent`. `--focus` biaise l'audit.
3. **Auditer** : intention (titre et description vs diff, scope creep) ; cohérence cross-fichiers (tous les artefacts d'une nouvelle entité présents) ; discipline projet (doc de feature, changelog, tests des zones critiques, verdict `product-strategist` pour une nouvelle feature) ; CI (vert ? sinon la PR ne se merge pas).
4. **Classer** chaque point avec la taxonomie ci-dessus, en citant `file:line`.
5. **Verdict** : **APPROVE** (0 must, ≤ 2 imo mineurs) · **COMMENT** (imo non bloquants) · **REQUEST_CHANGES** (≥ 1 must, ou imo cumulés, ou CI rouge).
6. Par défaut **dry-run** (affichage seul). Avec `--post`, après confirmation : `gh pr review <N> --comment|--approve|--request-changes --body "…"` (`--comment` par défaut).

## Mode `fix` — répondre aux commentaires de review

1. **Récupérer** : `gh pr view [N] --comments`, `gh pr view [N] --json reviews,comments`, `gh pr checks`.
2. **Classer** avec la taxonomie. Ordre : must → imo → nits (en lot) → q (peuvent débloquer le reste).
3. **Pour chaque must** : (a) **reproduire** le bug ou identifier la règle violée ; (b) **cause racine**, pas le symptôme ; (c) **fix ciblé**, uniquement le point relevé : si le commentaire réclame un grand refactor, répondre qu'il faut une issue séparée.
4. **Commit** : un **nouveau** commit par groupe cohérent (`fix(pr-review): <sujet>`), jamais `--amend`, jamais de force push, puis `git push`.
5. **Répondre** sur chaque commentaire traité (`Fixed in <sha>`) ; les `q` reçoivent une réponse texte.
6. `gh pr checks --watch` : si la CI échoue, reboucler.

## Refusé

- ❌ Créer une PR sans `/pre-pr` vert, ou la passer « ready » avant la CI
- ❌ Créer des labels à la volée, supprimer les commentaires HTML du template
- ❌ Approuver sans avoir lu tout le diff ; REQUEST_CHANGES sans `file:line`
- ❌ Des nits seuls justifiant un REQUEST_CHANGES
- ❌ `--amend` + force push sur une PR en review
- ❌ Ignorer un must parce que « le reviewer se trompe » : répondre d'abord, converger
- ❌ Sur-corriger : un refactor massif à l'occasion d'un nit

## Format de sortie

```
### PR <mode> — #<N> · <titre>
**Stats** : <fichiers>, +X/-Y, <commits> commits — **CI** : ✅ | ❌ <étape>
**Intention** : "<phrase>" — **Experts** : <liste>

🔴 must · 🟡 imo · 🟢 nits · 🔵 q   (file:line — problème — fix)
✅ Positif (factuel)

**Verdict** : APPROVE | COMMENT | REQUEST_CHANGES      (mode review)
**Plan** : [must #id] … → [imo] … → [nits batch] … → [q]   (mode fix)
**Action** : confirmer avant `gh pr create` / `--post` / `git push`
```
