# Anti-Patterns — catalogue générique

> Patterns interdits valables pour tout projet, et convention du catalogue.
> Les catalogues propres à une stack vivent dans `docs/anti-patterns-<stack>.md` (fournis par le pack de stack, ex : `anti-patterns-adonisjs.md`).
> Tout nouvel anti-pattern découvert en review est ajouté ici s'il est générique, sinon dans le catalogue de la stack ou du projet.

## Convention de tagging

| Tag | Sens |
|---|---|
| **P0** | Bloque le merge (sécurité, perte de données, régression certaine) |
| **P1** | À corriger avant merge ou avec ticket daté |
| **P2** | Dette tolérée, à planifier |

Chaque entrée : **Anti-Pattern → Solution → Sévérité**, avec `file:line` d'un exemple réel quand il existe. Les références à des entités du projet (`<PRIMARY_MODELS>`, services de stockage…) se traduisent via le `CLAUDE.md` du projet hôte.

---

## Workflow Agentic

### Anti-pattern P1 — Double-discipline gratuite

**Symptôme** : Claude invoque à la fois un skill projet ET son équivalent superpowers générique pour la même tâche.

**Exemples concrets** :
- `/feature` + `brainstorming` (le skill projet `/feature` invoque déjà `brainstorming` en interne)
- `code-reviewer` subagent + `requesting-code-review` skill (le subagent projet REMPLACE le skill superpowers)
- `/pre-pr` + `verification-before-completion` (sauf cas `gh pr create` qui combine `/pre-pr` + `finishing-a-development-branch`)

**Pourquoi c'est mauvais** :
- Coût tokens × 2 sur la même réflexion
- Friction utilisateur (Claude pose 2 fois les mêmes questions)
- Risque d'incohérence si les 2 outils proposent des verdicts contradictoires

**Solution** : appliquer la **règle d'or routage** définie dans [`docs/claude-config/setup.md`](claude-config/setup.md) §3 :

> Si un skill projet existe pour le contexte, il PRIME sur l'équivalent superpowers générique. Les skills superpowers s'invoquent uniquement quand aucun skill projet ne couvre le contexte (gap pur).

**Détection en review** : si un commit ou une session mentionne 2 skills couvrant le même axe, c'est un anti-pattern. Voir `setup.md` §3 pour des exemples de correspondance.

---

---

> **Règle d'ajout** : tout nouveau pattern découvert en code review → ajouter immédiatement ici (ou dans le catalogue de stack) + l'entrée courte dans le `CLAUDE.md` du projet.
