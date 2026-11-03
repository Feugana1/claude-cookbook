---
name: refactor
description: Incremental refactor of a file or module with unchanged behavior - extract method, reduce complexity, split files over the project's size limits, extract duplication only at the right threshold. Tests green before AND after. Triggers when user says "refactor", "simplifier", "splitter", or when a size ratchet or duplication check fails.
argument-hint: "<file or module>"
---

# /refactor — refactor incrémental discipliné

Refactorer un fichier ou un module **sans changer le comportement** : lisibilité, split au-dessus des limites du projet, extraction de duplication.

## Quand l'utiliser

- Un fichier dépasse les limites du projet (ratchet de taille en échec).
- Duplication détectée (`scan-secu.sh` step jscpd, ou à la lecture).
- Complexité élevée sur une méthode.
- L'utilisateur demande « refactor », « simplifier », « splitter ».

**Pas ici** : un bug fonctionnel (diagnostiquer d'abord, agent `analyzer` si la cause est floue) ; l'ajout d'une feature (`/feature`) ; un changement d'API publique (breaking change : en discuter d'abord).

## Pré-requis absolu : base verte

Lancer les checks du projet avant de toucher quoi que ce soit (tests, typecheck, lint : commandes du `package.json` / `Makefile` / `CLAUDE.md`). **Base rouge = on ne refactore pas** : corriger d'abord. Une zone critique sans tests : écrire d'abord des tests de non-régression.

## Méthode

1. **Cartographier** : `wc -l`, nombre de méthodes publiques, préoccupations distinctes, callers (`grep -rn "<symbole>"`).
2. **Choisir la technique** :

| Symptôme | Technique |
|---|---|
| fichier au-dessus de la limite | split par domaine / responsabilité, helpers partagés dans un module dédié |
| méthode > 50 lignes ou complexité élevée | Extract Method |
| duplication ≥ 5 occurrences | Extract Helper |
| duplication 3-4 occurrences | **ne pas extraire** : trois lignes semblables valent mieux qu'une abstraction prématurée |
| conditionnels imbriqués | early return, guard clauses |
| `switch`/`if` sur un type, > 3 branches stables | Strategy / polymorphisme |
| prop drilling > 3 niveaux, stable | contexte ou store local |

3. **Petites unités atomiques**, un commit chacune : transformer → tests + typecheck verts → `git add` → unité suivante. Rouge : annuler l'unité et comprendre (import manquant, signature changée). Jamais un refactor massif en un commit (impossible à relire et à bisecter).
4. **Ratchet de taille** : si le projet a une baseline de tailles de fichiers, la régénérer après un split légitime et la commiter.
5. **Vérifier le comportement** : tests existants verts, scénario manuel du golden path si l'UI est touchée.
6. **Review** : si le diff cumulé dépasse ~300 lignes, passer par le reviewer final avant de commiter ; les experts de la stack (architect, linter de templates, migrations) pour la zone touchée, s'ils sont installés.

## Refusé

- ❌ Refactor + feature dans le même commit
- ❌ Refactor sans base verte
- ❌ Extraire un helper à 3 occurrences
- ❌ Renommer un symbole public sans avoir cherché ses callers
- ❌ Sur-abstraction « future-proof » (YAGNI)
- ❌ Refactor cosmétique : du bruit dans le diff

## Format de sortie

```
### Refactor — plan
**Cible** : <file ou module> — taille <X> L (limite <Y>) — méthodes publiques <N> — duplication <sites>
**Base** : tests ✅/❌ · typecheck ✅/❌ · lint ✅/❌    (❌ = bloqué : corriger d'abord)
**Techniques** : <liste> — justification
**Unités** : 1. … → commit · 2. … → commit · 3. régénérer la baseline si split
**Vérification finale** : tests · typecheck · ratchet · comportement inchangé
**Action** : confirmer le plan, puis boucle par unité
```
