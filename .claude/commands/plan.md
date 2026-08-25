---
description: Passe en mode plan explicite pour tâches ≥ 3 étapes ou changements structurels. Plan écrit → attend approval avant execute. Complémentaire `/feature` (features product) — `/plan` = refactor / architecture / infra sans strategic gate.
---

# /plan — Mode plan explicite (refactor / architecture / infra)

Active mode plan pour tâches complexes NON-feature (refactor, restructuration, migration, infra, chore majeur). Écrit plan détaillé, attend approval user via `ExitPlanMode`, PUIS execute.

**Distinct de `/feature`** :
- `/feature` = nouvelle feature user-facing → passe par `product-strategist` couche 0 (verdict GO/NO-GO)
- `/plan` = refactor / infra / migration → skip strategic gate, direct au plan technique

## When to invoke

- Tâche ≥ 3 étapes
- Décision architecturale (split module, nouveau service, nouvelle table sans nouvelle feature)
- Touche ≥ 2 fichiers existants
- Migration DB ou changement contrat API/route
- Infra / CI / build system changes
- Refactor structurel (déplacer modules, extraire package)

## When NOT to invoke

- Bugfix < 5 min, 1 fichier → action directe
- Nouvelle feature user-facing → `/feature` (couche 0 strategic gate)
- Tâche exploratoire "je regarde comment X marche" → question directe

## Méthode

### 1. Comprendre la demande

Lire :
- Description user
- Fichiers cibles s'ils sont mentionnés (`Read` si nécessaire)
- CLAUDE.md du projet (conventions)
- `docs/lessons.md` §2.1 plan mode

Reformuler en 1 phrase la demande AVANT plan. Si ambiguë → poser 1-3 questions clarification, PAS plan sur assomption.

### 2. Cartographier le scope

- Grep patterns / callers pour comprendre impact
- Identifier files touchés (create/modify/delete)
- Identifier couplages (breaks / breaking changes)

### 3. Structurer le plan

Format standardisé :

```
## Plan : <titre court>

### Contexte
<1-3 phrases : d'où on part, où on va, pourquoi>

### Contraintes
- <contrainte tech / temps / backwards-compat>
- <invariant à préserver>

### Approche
<1-3 phrases : stratégie haut niveau>

### Étapes détaillées
1. <étape atomique — file touché — action précise>
2. <étape 2>
3. <étape N>

### Vérification par étape
- Après étape 1 : `<commande de test>`
- Après étape 2 : ...
- Global : `npm test && npm run typecheck && bash scan-secu.sh --diff`

### Rollback plan
Si étape N fail :
- <comment revenir en arrière>
- <si commit fait : quel reset>

### Files touchés
- CREATE : <liste>
- MODIFY : <liste>
- DELETE : <liste>

### Experts à invoquer post-implém
- <back-architect> — vérifier conventions
- <security-multitenant> — si backend metier
- <code-reviewer> — avant commit final

### Risques identifiés
| Risque | Mitigation |
|---|---|
| <r1> | <m1> |
| <r2> | <m2> |

### Estimated effort
- Temps : <heures>
- Fichiers : <count>
```

### 4. Presenter via ExitPlanMode

Utiliser tool `ExitPlanMode` (si disponible) OU présenter le plan formaté en attendant approval user explicite ("go", "ok", "approuvé").

**Ne PAS coder sans approval user.**

### 5. Execute step-by-step

Après approval :
1. TaskCreate pour tracker étapes
2. Exécuter séquentiellement
3. Après chaque étape : vérification prescrite
4. Si déviation du plan : ARRÊTER, replanifier, re-approval (cf `docs/lessons.md` §2.1 "si dévie, arrêter et replanifier, pas pousser le delta")

### 6. Closure

- Verification globale (tests + typecheck + scan-secu)
- Invoquer `code-reviewer` avant commit
- `/commit` ou `/semantic-commit` selon scope

## Discipline

- **Pas de code avant approval** — règle absolue
- **Un plan = un scope** — pas de "tant que j'y suis" ajouté en cours
- **Deviation = replan** — pas de "j'ai vu que X aussi donc j'ai fait Y"
- **Vérification par étape** — pas juste à la fin

## Anti-patterns

- ❌ "Je code d'abord, je plan après"
- ❌ Plan de 50 étapes → splitter en sous-plans
- ❌ Plan sans "Rollback plan"
- ❌ Plan sans "Vérification par étape"
- ❌ Ignorer clarifications user avant plan

## Sources

- `docs/lessons.md` §2.1 Plan mode par défaut
- `docs/lessons.md` §1.4 Goal-Driven Execution (critère succès vérifiable)
- Cookbook `/feature` : `.claude/skills/feature/SKILL.md` (pour features product-facing)
- Superpowers `writing-plans` skill (pattern générique)
