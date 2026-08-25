---
description: Refactor incrémental d'un fichier ou module. Extraction méthode, réduction complexité, split file au-dessus des limites §14 (300/400/800L). Comportement inchangé (tests verts avant ET après).
---

# /refactor — Refactor incrémental discipliné

Refactor un fichier ou un module **sans changer le comportement**. Cible : lisibilité, split au-dessus des limites §14, extraction de duplication.

## When to invoke

- Un fichier dépasse les limites §14 (`controller` 300L / `service` 400L / `template` 800L) et le ratchet CI fail
- Duplication détectée (`scan-secu.sh` step 11 — jscpd)
- Complexité cyclomatique élevée sur une méthode
- Le user demande "refactor", "simplifier", "splitter"

## When NOT to invoke

- Le fichier a un bug fonctionnel → utiliser `/fix-error` d'abord
- Le refactor ajoute une feature → utiliser `/feature` (couche 0 strategic gate)
- Le refactor change une API publique → c'est un breaking change, discuter d'abord

## Pré-requis absolu — tests verts

**Avant tout refactor** :

```bash
npm test           # OU la commande test du projet
npm run typecheck
npm run lint
```

Si tests fail avant refactor : `/fix-error` d'abord. Ne PAS refactor sur base rouge.

## Méthode

### 1. Cartographier le fichier / module

- `wc -l <file>` — mesurer taille vs limite §14
- Compter méthodes publiques (Read + grep `public\|export`)
- Identifier responsabilités : combien de préoccupations distinctes ?
- Grep callers : `grep -rn "<functionName>" .` — quels sites d'usage ?

### 2. Choisir la technique

| Symptôme | Technique | Justification |
|---|---|---|
| Fichier > limite §14 | **Split par domaine** en sous-controllers/services + helpers `_helpers/` (cf `CLAUDE.md §14`) | Chaque fichier = 1 préoccupation |
| Méthode > 50L ou cyclomatique élevée | **Extract Method** vers méthodes privées ou helper | Lisibilité + testabilité |
| Duplication ≥ 5 occurrences | **Extract Helper** vers `_helpers/<domain>_helper.ts` | Cf `CLAUDE.md §14` seuil 5+ |
| Duplication 3-4 occurrences | **NE PAS extraire** — laisser dupliqué | Cf `docs/lessons.md` §1.2 "3 lignes ≠ helper" |
| Conditionnels imbriqués profonds | **Early return** / **guard clauses** | Réduit imbrication, lisibilité |
| Switch/if sur type | **Pattern Strategy** / polymorphisme | Si + de 3 branches ET usage stable |
| Prop drilling profond | **Context** / **Store** local | Uniquement si prop drilling > 3 niveaux ET stable |

### 3. Refactor par petites unités

**Une unité = un commit atomique**. Boucle :

1. Extract / split / rename
2. `npm test` + `npm run typecheck` — doivent rester verts
3. Si vert : `git add` + prochaine unité
4. Si rouge : `git stash` OU rollback → analyser pourquoi (souvent : import manquant, signature changée)

**Anti-pattern refusé** : refactor massif en un seul commit. Impossible à review, impossible à bisect si régression.

### 4. Baseline ratchet post-split

Si le refactor split un fichier qui était grandfathered dans `scripts/file-size-baseline.json` :

```bash
node scripts/check-file-sizes.js --baseline
```

→ régénère la baseline avec les nouvelles tailles (progression du ratchet). Commit la baseline updated.

### 5. Vérifier comportement inchangé

- Tests existants restent verts — obligatoire
- Si feature critique sans tests : écrire tests de non-régression AVANT de refactor (cf `docs/lessons.md` §1.4 "Goal-Driven Execution")
- Golden path manuel si UI touché — tester scenarios visibles

### 6. Invoquer expert cookbook si scope large

Si refactor touche :
- Back services/controllers → `back-architect` (couche 1) après refactor pour audit conventions
- Templates .edge → `edge-anti-patterns` (couche 4) après refactor
- Migrations → `migration-reviewer` (couche 2)
- Diff cumulé ≥ 300L → `code-reviewer` (couche 5) avant commit

## Anti-patterns refusés

- ❌ **Refactor + feature dans le même commit** — split obligatoire
- ❌ **Refactor sans tests verts avant** — impossible de valider comportement inchangé
- ❌ **Extract helper à 3 occurrences** — cf `docs/lessons.md` §1.2 (seuil 5+)
- ❌ **Renommer publiquement sans grep callers** — casse consumers silencieux
- ❌ **Sur-abstraction "future-proof"** — YAGNI, ajouter quand le besoin réel apparaît
- ❌ **Refactor "cosmétique"** — reformat sans valeur — bruit dans le diff

## Format de sortie

```
### Refactor — plan

**Cible** : `<file ou module>`
**Métriques actuelles** :
- Taille : <X>L (limite <Y>L cf §14)
- Méthodes publiques : <N>
- Duplication détectée : <sites si applicable>
- Complexité : <estimation qualitative>

**Tests baseline** :
- [x/❌] `npm test` — <résultat>
- [x/❌] `npm run typecheck`
- [x/❌] `npm run lint`

**BLOQUÉ si baseline ❌** — fix-error d'abord.

**Technique(s) choisie(s)** :
- <Extract Method | Split File | Extract Helper | Guard Clauses | Strategy>
- Justification : <référence à §14 ou docs/lessons.md>

**Plan par unités atomiques** :
1. <unité 1 : extract private method X> → commit
2. <unité 2 : split sub-controller Y> → commit
3. <unité 3 : extract helper Z si 5+ callers> → commit
4. Regen baseline si split → `--baseline`
5. Invocation expert : <back-architect | edge-anti-patterns | code-reviewer>

**Vérification finale** :
- [ ] Tests verts
- [ ] Typecheck OK
- [ ] Ratchet OK
- [ ] Comportement inchangé (manuel si UI)

**Action** :
- Confirmer plan
- Boucle par unité, commit après chaque
```

## Sources

- `CLAUDE.md §14` — limites fichiers + helpers `_helpers/` seuil 5+
- `docs/lessons.md` §1.2 Simplicity First, §1.3 Surgical Changes, §1.4 Goal-Driven Execution
- `scripts/check-file-sizes.js` — ratchet + `--baseline` regen
- Cookbook `back-architect` (couche 1), `code-reviewer` (couche 5)
