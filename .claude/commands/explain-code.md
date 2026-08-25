---
description: Explique clairement fonctionnalité + logique d'un code (fonction, module, service). Structure : intent → flow → data → edge cases → callers. Didactique, pas paraphrase.
---

# /explain-code — Expliquer code sélectionné

Explique code (fonction, classe, module, service) pour :
- Onboarding nouveau dev
- Compréhension avant refactor
- Documentation module non-doc

**But** : rendre le pourquoi et le comment évidents. Pas paraphraser ligne-par-ligne — expliquer INTENT + FLOW + DÉCISIONS.

## Options

- `--level beginner|intermediate|expert` (défaut intermediate)
- `--focus flow|data|error|perf` — biais explication
- `--diagram` — inclut ASCII diagram flow / relation

## Méthode

### 1. Lire cible + contexte

- Le fichier cible complet
- Les 2-3 imports critiques
- Les callers (grep pour usages) — au moins 3
- Tests associés si présents (révèlent intent)

### 2. Structure de l'explication

**A. Résumé 1 phrase**
> `<Module/Fonction>` : <verbe> <quoi> pour <pourquoi> (utilisé par <callers>).

**B. Intent (pourquoi ça existe)**
- Quel problème résout-il ?
- Alternative envisagée puis rejetée ? (si visible)
- Cité par quel doc (`CLAUDE.md`, `docs/architecture.md`) ?

**C. Flow (le comment haut niveau)**
Décrire les étapes principales, chaque étape 1 ligne :
1. <étape 1>
2. <étape 2>
3. <étape N>

Diagram ASCII si `--diagram` :
```
Input → Validate → Process → Save → Notify → Response
             ↓ (fail)
          ErrorHandler
```

**D. Data flow**
- Input : type, source, contraintes
- Output : type, side effects (DB write, email sent, event emitted)
- État partagé (globals, cache, session)

**E. Edge cases**
- Null / empty / boundary values traités ?
- Erreurs métier vs erreurs système
- Retry / fallback / timeout

**F. Callers (usage réel)**
Lister 2-3 callers avec brief usage :
- `<file:line>` : <contexte usage> (ex: contrôleur POST /invoices)

**G. Décisions notables**
Si le code fait un choix non-évident (perf, sécurité, backwards-compat) :
- Choix : <ce qui a été fait>
- Why : <raison inférée depuis commit / code / doc>

**H. Ce qui pourrait surprendre**
- Anti-patterns évités (ex: `.forTenant()` wrapper obligatoire cookbook)
- Convention projet-specific (ex: `swallow()` helper)
- Bug historique corrigé (memory / docs/lessons.md)

## Adapter au level

**beginner** :
- Éviter jargon (expliquer TS types, async/await)
- Diagram ASCII inclus par défaut
- Comparer à concepts connus ("like a REST controller in Express")

**intermediate** (défaut) :
- Assume connaissance stack (AdonisJS / TS / Lucid)
- Focus intent + décisions + gotchas

**expert** :
- Ultra-condensé
- Focus décisions non-triviales seulement
- Skip flow évident, focus edge cases + trade-offs

## Format de sortie

```
### Explain — `<path>` (level: <level>)

**Résumé 1-phrase** :
> <phrase>

**Intent** :
> <pourquoi ça existe + doc réf>

**Flow** :
1. <étape>
2. <étape>
3. <étape>

<diagram ASCII si --diagram>

**Data flow** :
- Input : <type + source + contraintes>
- Output : <type + side effects>
- État partagé : <si applicable>

**Edge cases traités** :
- <cas 1>
- <cas 2>
- <cas non traité / à surveiller>

**Callers (usage réel)** :
- `file:line` — <contexte>
- `file:line` — <contexte>

**Décisions notables** :
- <décision> — <why>

**Ce qui pourrait surprendre** :
- <point non-évident + raison>

**Pointers pour aller plus loin** :
- `docs/<X>.md` — doc source
- Tests : `<test path>` — révèle contrat exact
```

## Anti-patterns

- ❌ Paraphraser ligne-par-ligne — inutile, code déjà lisible
- ❌ Recopier docstring — pas de valeur ajoutée
- ❌ Skip callers — un module se comprend par usage
- ❌ Skip décisions — le pourquoi > le quoi
- ❌ Level "expert" avec explications intro

## Sources

- Code cible + imports + callers
- `CLAUDE.md` du projet (conventions)
- `docs/architecture.md` si module architectural
- Tests (contrat comportemental)
- Memory du projet (décisions passées)
