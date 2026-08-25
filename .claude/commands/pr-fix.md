---
description: Répond aux commentaires de review d'une PR. Classifie must/imo/nits/q, priorise, propose fixes ciblés, teste. Fait un nouveau commit (jamais amend).
---

# /pr-fix — Répondre aux review comments d'une PR

Traite les commentaires de review de la PR courante (ou spécifiée). Approche 3 étapes : **classifier → prioriser → fixer**. Nouveau commit par fix cohérent (jamais amend/force push).

## Méthode

### 1. Récupérer les comments

```bash
# PR courante (depuis branche)
gh pr view --comments
gh pr view --json reviews,comments,reviewRequests

# Ou PR spécifique
gh pr view <N> --comments

# CI checks
gh pr checks
```

### 2. Classifier

Utiliser convention **must / imo / nits / q** :

| Marqueur | Signification | Priorité |
|---|---|---|
| 🔴 **must** | Bug, sécurité, violation convention, breaking | P0 — fix obligatoire |
| 🟡 **imo** | Suggestion architecte, amélioration structure, refactor | P1 — fix recommandé |
| 🟢 **nits** | Typo, style, indentation, naming mineur | P2 — fix si trivial |
| 🔵 **q** | Question / demande de clarification | Répondre en commentaire, pas de code |

**Ordre d'exécution** : `must` d'abord, `imo` ensuite, `nits` en batch, `q` en dernier (peut débloquer les autres).

### 3. Approche 3 étapes pour chaque comment must

#### Étape 3a — Reproduire

- Bug reporté ? → reproduire d'abord (curl, screenshot, requête SQL). Cf `docs/lessons.md` §1.1 "clarifier avant d'implémenter".
- Convention violée ? → identifier la règle source (`CLAUDE.md §X`, `docs/anti-patterns.md`, expert cookbook).

#### Étape 3b — Root cause

Ne PAS patch le symptôme. Identifier le pourquoi.

- Régression comportement ? → diff avec version pré-régression, tracer le change
- CI fail ? → lire log complet, identifier étape exacte, tester localement

#### Étape 3c — Fix ciblé

Appliquer surgical change (cf `docs/lessons.md` §1.3) — corriger UNIQUEMENT le point reviewé. Pas de "tant que j'y suis".

Si le comment demande un refactor large → répondre en commentaire pour splitter en issue séparée, ne pas ratisser cette PR.

### 4. Commit + push

**Un nouveau commit** par groupe de fixes cohérents. Jamais `--amend`. Jamais force push.

```bash
git add <files-fixed>
git commit -m "fix(pr-review): <résumé fix must-comments batch 1>"
git push
```

Message : `fix(pr-review): <sujet>` — mention explicite que c'est en réponse à review.

### 5. Répondre aux comments

Sur chaque comment traité :

```bash
gh pr review --comment "Fixed in <sha>. <optional context>"
```

Ou via UI GitHub. Marquer comme résolu si le comment supporte.

Pour les `q` (questions) : répondre directement en comment (pas de code).

### 6. Vérifier CI verte

```bash
gh pr checks --watch
```

Si nouveau CI fail : boucler `/pr-fix` sur les nouveaux errors.

## Anti-patterns

- ❌ `git commit --amend` puis `git push --force` (blocked par settings, casse review context)
- ❌ Fixer tous les comments en un seul commit fourre-tout (splitter par domaine)
- ❌ Ignorer un `must` "parce que je pense que le reviewer se trompe" — répondre en commentaire d'abord, converger
- ❌ Sur-corriger : refactor massif à l'occasion d'un `nits` → refuser, ouvrir issue séparée
- ❌ Pousser fix sans avoir reproduit le bug d'abord

## Format de sortie

```
### PR fix — plan d'action

**PR** : #<N> — <title>
**Comments récupérés** : <total>
  - 🔴 must : <count>
  - 🟡 imo  : <count>
  - 🟢 nits : <count>
  - 🔵 q    : <count>

**CI status** : ✅ green | ❌ fail on <step>

**Plan** :
1. [must #<comment-id>] <résumé> → fix approach
2. [must #<comment-id>] <résumé> → fix approach
3. [imo #<comment-id>] <résumé> → fix ou décliner justifié
4. [nits batch] <count> nits — 1 commit unique
5. [q #<comment-id>] <réponse texte, pas de code>

**Ordre d'exécution** : must → imo → nits → q

**Action** :
- Confirmer plan
- Fix un par un (ou batch nits) avec commit + push après chaque
- Re-lancer `/pr-fix` si nouveaux comments
```

## Sources

- Cookbook `/commit` : `.claude/commands/commit.md` (discipline commit)
- Cookbook `code-reviewer` : `.claude/agents/code-reviewer.md` (couche 5 — invocable pour re-review post-fix)
- Cookbook lessons §1.3 surgical changes
- gh CLI review commands : https://cli.github.com/manual/gh_pr_review
