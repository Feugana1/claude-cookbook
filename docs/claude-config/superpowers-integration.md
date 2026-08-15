# Superpowers ↔ Stack MyProject — Doc d'intégration

> **Statut** : actif depuis 2026-05-31. Source unique sur quand utiliser un skill superpowers vs un skill/subagent projet.
> **Spec** : [`docs/superpowers/specs/2026-05-31-superpowers-integration-design.md`](../superpowers/specs/2026-05-31-superpowers-integration-design.md)

## 1. Contexte

Le plugin `superpowers@claude-plugins-official` v5.1.0 a été installé le 2026-05-31. Il apporte 14 skills génériques qui couvrent la **discipline de session Claude** (process amont/pendant/aval) : `brainstorming`, `writing-plans`, `executing-plans`, `subagent-driven-development`, `test-driven-development`, `systematic-debugging`, `using-git-worktrees`, `dispatching-parallel-agents`, `verification-before-completion`, `requesting-code-review`, `receiving-code-review`, `finishing-a-development-branch`, `using-superpowers`, `writing-skills`.

La stack Claude MyProject existante (cf [`experts.md`](experts.md)) est mature : 4 skills custom projet (`/feature`, `/ux-review`, `/secu`, `/pre-pr`) + 12 subagents en 6 couches + 2 hooks. Plusieurs skills superpowers ont un **équivalent projet** (ex : `/feature` ↔ `brainstorming + writing-plans`, `code-reviewer` ↔ `requesting-code-review`). Sans règle de routage explicite, Claude risque d'enfiler les 2 disciplines "par sécurité" → coût tokens + friction + redondance. Cette doc tranche : **le skill projet, projet-aware, prime sur l'équivalent superpowers générique.**

## 2. Architecture à 2 couches

Les 2 stacks sont **orthogonales et complémentaires** : superpowers décrit *comment on travaille* (process), la stack projet décrit *sur quoi on travaille* (connaissance domaine).

```
┌────────────────────────────────────────────────────────────────────────┐
│  COUCHE PROCESS (superpowers, 14 skills) — comment on travaille        │
│                                                                        │
│  Amont    : brainstorming → writing-plans → executing-plans            │
│  Pendant  : subagent-driven-dev, dispatching-parallel-agents,          │
│             test-driven-development, systematic-debugging,             │
│             using-git-worktrees                                        │
│  Aval     : verification-before-completion → requesting-code-review →  │
│             receiving-code-review → finishing-a-development-branch     │
│  Meta     : using-superpowers (orchestre tout), writing-skills         │
├────────────────────────────────────────────────────────────────────────┤
│  COUCHE PROJET (existant, intacte) — quoi on travaille                 │
│                                                                        │
│  N3 Skills      : /feature  /ux-review  /secu  /pre-pr                 │
│  N2 Subagents   : 12 experts en 6 couches (couche 0→5 experts.md)      │
│  N1 Hooks       : dispatch-expert.sh + precommit-check.sh              │
│  Permissions    : .claude/settings.json (deny/ask)                     │
└────────────────────────────────────────────────────────────────────────┘
                              ↓
         Ordre canonique :
   process amont → process pendant → expert projet → process aval
```

> **Superpowers décrit la discipline de session. Les experts projet apportent la connaissance domaine.**
> Les deux sont complémentaires, pas concurrents.

## 3. Règle d'or

**Si un skill projet existe pour le contexte, il PRIME sur l'équivalent superpowers générique.**

Les skills superpowers s'invoquent uniquement quand :
- Aucun skill projet ne couvre le contexte (**gap pur** : `systematic-debugging`, `test-driven-development`, `using-git-worktrees`, `writing-skills`, `dispatching-parallel-agents`, `subagent-driven-development`)
- Le contexte sort du domaine MyProject (ex : travailler sur la stack Claude elle-même)

## 4. Matrice de routage

| Contexte / déclencheur | Skill / agent à invoquer | NE PAS aussi invoquer |
|---|---|---|
| **Nouvelle feature MyProject** (UI ou backend métier) | `/feature` (qui chaîne `brainstorming` + `product-strategist` + `writing-plans` en interne) | ❌ pas `brainstorming` directement, ❌ pas `writing-plans` directement |
| **Refactor / changement structurel projet** non-feature | `brainstorming` (superpowers) → `writing-plans` → `executing-plans` | ❌ pas `/feature` (réservé features) |
| **Bugfix simple < 5 min, < 2 fichiers** | Action directe, pas de skill | ❌ ni `/feature`, ni `brainstorming`, ni `writing-plans` |
| **Bug non trivial / behavior unexpected** | `systematic-debugging` (superpowers) puis fix | — |
| **Avant `git commit` (diff non-trivial)** | `code-reviewer` subagent (couche 5 projet) | ❌ pas `requesting-code-review` (doublon) |
| **Avant `git push`** | `/secu` (wrap `scan-secu.sh`) | ❌ pas `verification-before-completion` (sauf gap) |
| **Avant `gh pr create`** | `/pre-pr` (lint+typecheck+build+sizes) PUIS `finishing-a-development-branch` | ✅ les 2 ensemble (axes distincts : qualité technique vs décision merge/PR/cleanup) |
| **Avant tout claim "terminé"** | `verification-before-completion` (superpowers) | — (gap pur) |
| **Implémenter une feature avec tests requis** (zone critique NF525/security/paiement) | `test-driven-development` (superpowers) | — (gap pur) |
| **2+ tâches indépendantes à paralléliser** | `dispatching-parallel-agents` (superpowers) | — (gap pur) |
| **Travailler en isolation d'un workspace** | `using-git-worktrees` (superpowers) | — (gap pur) |
| **Créer un nouveau skill custom** | `writing-skills` (superpowers) | — (gap pur, méta) |
| **Audit UX d'un écran config** | `/ux-review` (projet-aware) | ❌ pas `brainstorming` |
| **Travailler sur la stack Claude elle-même** | Skills superpowers directs (`brainstorming`, `writing-plans`, etc.) | ❌ pas `/feature` (qui parle features MyProject) |
| **Question simple / requête conversationnelle** (ex : "que fait ce fichier ?") | Réponse directe, aucun skill | ❌ pas `using-superpowers`, ❌ pas `brainstorming`. La méta-règle "invoke skill before any response" de `using-superpowers` s'applique aux **tâches**, pas aux questions purement informationnelles. |

## 5. Cas limites

- **`code-reviewer` vs `requesting-code-review`** : `code-reviewer` est un *subagent* (Couche 5 projet), `requesting-code-review` est un *skill* (superpowers). Ils ne sont pas au même niveau — `code-reviewer` est l'implémentation projet de `requesting-code-review`. Doc explicite : "pour ce projet, le subagent `code-reviewer` remplace l'invocation du skill `requesting-code-review`".
- **`/pre-pr` + `finishing-a-development-branch`** : seule combinaison OK des 2 ensemble (axes distincts).
- **Plan mode §17.1** : reste actif comme convention CLAUDE.md, devient trigger pour `writing-plans`.

## 6. Anti-pattern "Double-discipline gratuite"

**Anti-pattern P1 — Double-discipline gratuite** : invoquer à la fois un skill projet ET son équivalent superpowers générique (ex : `/feature` + `brainstorming`). Le skill projet est censé déjà appliquer la discipline superpowers en interne. Le faire en double = coût en tokens, friction utilisateur, redondance pédagogique. Toujours **un seul des deux**, selon la matrice §4.

**Exemple concret** :

```
❌ ANTI-PATTERN
User: "ajoute la feature gallery-tag-filter"
Claude: invoke brainstorming  ← inutile, /feature le fait
Claude: invoke /feature       ← /feature relance brainstorming en interne
        → 2× le coût, le user voit 2 sessions brainstorming
```

```
✅ PATTERN CORRECT
User: "ajoute la feature gallery-tag-filter"
Claude: invoke /feature
  /feature: invoke brainstorming (chaîné en interne)
  /feature: invoke product-strategist (verdict GO/REVOIR/NO-GO)
  /feature: invoke writing-plans (chaîné en interne)
  /feature: dispatch experts selon scope
```

La règle est aussi formalisée dans [`docs/anti-patterns.md`](../anti-patterns.md) §Workflow Agentic.

## 7. Skills projet — table de correspondance superpowers

| Skill projet | Équivalent superpowers | Différence | Quand utiliser le projet |
|---|---|---|---|
| `/feature` | `brainstorming` + `writing-plans` | Projet ajoute `product-strategist` (couche 0 différenciation) + dispatch experts | Toujours pour features MyProject |
| `/ux-review` | (aucun équivalent direct) | Projet-aware : 6 axes + density gate + Digital Curator | Audit UI projet |
| `/secu` | `verification-before-completion` (partiel) | Projet wrap `scan-secu.sh` (24 étapes) | Avant push |
| `/pre-pr` | `verification-before-completion` + `finishing-a-development-branch` (partiel) | Projet enchaîne lint+typecheck+build+sizes | Avant `gh pr create` |

| Subagent projet | Équivalent superpowers | Différence | Quand utiliser le projet |
|---|---|---|---|
| `code-reviewer` (couche 5) | `requesting-code-review` | Projet-aware : NF525, multi-tenant, charte | Toujours avant commit non-trivial |
| `back-architect` / `front-curator` (couche 1) | (aucun équivalent) | Projet-specific | Toujours |
| Couches 2-3-4 | (aucun équivalent) | Domain knowledge profond | Selon scope |

## 8. Cas d'usage type

### 8.1 Nouvelle feature
```
User: "ajoute la feature X"
Claude: invoke /feature
  /feature: invoke brainstorming (superpowers)
  /feature: invoke product-strategist (couche 0 projet)
  /feature: invoke writing-plans (superpowers)
  /feature: dispatch experts couches 1-3 selon scope
```

### 8.2 Bug non trivial
```
User: "j'ai un bug bizarre sur Y"
Claude: invoke systematic-debugging (superpowers — gap pur)
  systematic-debugging: hypothèses → reproduction → root cause
Claude: fix + invoke code-reviewer (couche 5 projet) avant commit
```

### 8.3 Refactor structurel
```
User: "refactore le module Z"
Claude: invoke brainstorming (superpowers — pas une feature)
Claude: invoke writing-plans (superpowers)
Claude: execute via subagent-driven-development OU executing-plans
Claude: invoke /pre-pr avant gh pr create
```

## 9. Évolution

- Ajout d'un nouveau skill projet → mettre à jour §7 (table correspondance)
- Évolution superpowers (nouveau skill du plugin) → évaluer s'il comble un gap projet ou si un skill projet le couvre déjà
- Audit usage (Phase B item B6) trimestriel → ajuster matrice §4 selon douleur observée
