---
name: multi-agent
description: Dispatch parallèle de N experts cookbook sur un même fichier/diff → rapport unifié consolidé. Pattern multi-perspective (architecture + sécurité + data-access + linter en //) OU adversarial (debate 2 experts contradictoires). Use when user says "audit complet ce fichier", "multi-perspective review", "3 experts sur ce diff", "/multi-agent <path> <experts>".
---

# /multi-agent — Dispatch parallèle N experts + synthèse

Lance plusieurs experts cookbook **en parallèle** sur le même fichier / diff, puis synthétise leurs findings en un seul rapport dédupliqué et rangé par sévérité.

Deux modes :
- **PARALLEL** (défaut) : N experts indépendants, perspectives complémentaires — synthèse union
- **DEBATE** : 2 experts avec verdicts potentiellement opposés — synthèse dialectique + arbitrage

## When to invoke

- Audit exhaustif d'un fichier critique (nouveau service metier, controller sensible, migration risquée)
- Diff PR volumineux touchant plusieurs domaines (back + front + DB + i18n)
- Décision architecturale contradictoire (ex: `back-architect` propose split A vs `security-multitenant` préfère structure B)
- Le user tape `/multi-agent <path> <expert1,expert2,...>` OU `/multi-agent debate <expert1,expert2> <path>`

## When NOT to invoke

- Fichier trivial (< 100L, pas de logique métier) — utiliser un seul expert cible
- Bugfix ponctuel — utiliser `/fix-error` ou expert unique
- Nouvelle feature — utiliser `/feature` (qui dispatch déjà les couches 1-3 en interne)

## Experts disponibles (cookbook)

| Couche | Expert | Model | Scope |
|---|---|---|---|
| 0 | `product-strategist` | sonnet | Différenciation produit (features seulement) |
| 1 | `back-architect` | sonnet | Conventions AdonisJS, tailles, naming, structure |
| 2 | `security-multitenant` | sonnet | Isolation, IDOR, CSRF, soft-delete, effectiveUserId |
| 2 | `data-access-reviewer` | haiku | ORM anti-patterns, storage, cache TTL |
| 2 | `migration-reviewer` | sonnet | Migrations DB (§9 DO/DON'T) |
| 3 | `workflow-email` | sonnet | Mustache/ICU, sync/sendLater, layout emails |
| 4 | `edge-anti-patterns` | haiku | Patterns Edge/Alpine grepables |
| 5 | `code-reviewer` | sonnet | Review PR-style senior orchestrateur |
| — | `reviewer` | opus | Générique (lisibilité/maintenabilité hors stack) |
| — | `analyzer` | opus | Root cause investigation |

Les experts projet-specific installés localement (`nf525-accounting`, `shop-marketplace`, `<domain>`, front-architect projet-specific…) sont également dispatchables — le skill lit `.claude/agents/*.md` du projet et propose les experts disponibles.

## Méthode — mode PARALLEL

### 1. Détecter scope + suggérer experts

```bash
# Fichier cible ou diff staged
if [ -n "$FILE_PATH" ]; then
  wc -l "$FILE_PATH"
  head -20 "$FILE_PATH"                    # header / imports pour détecter stack
else
  git diff --cached --stat
fi

# Lister agents disponibles
ls .claude/agents/*.md
```

Selon le path :

| Path modifié | Experts recommandés (PARALLEL) |
|---|---|
| `app/controllers/**/*.ts` | `back-architect` + `security-multitenant` + `data-access-reviewer` |
| `app/services/**/*.ts` | `back-architect` + `security-multitenant` + `data-access-reviewer` (+ domain expert projet-specific si match) |
| `app/models/**/*.ts` | `back-architect` + `data-access-reviewer` (+ domain-expert projet si table sensible) |
| `database/migrations/**/*.ts` | `migration-reviewer` (+ domain-expert projet si table sensible) |
| `resources/views/**/*.edge` | front-architect projet-specific si présent + `edge-anti-patterns` |
| Diff cross-domain (back + front + DB) | Tous les experts pertinents en //, `code-reviewer` final |

### 2. Dispatch parallèle

Invoquer chaque expert via `Agent` tool avec `subagent_type: <expert-name>`. Message chaque expert avec :

- Le path du fichier (ou diff via `git diff --cached`)
- Consigne explicite : "Audit selon ta règle d'or. Ne PAS auditer hors de ton scope. Format standardisé P0/P1/Quick wins/Déjà correct."
- Aucun contexte de fichier — laisser l'expert Read lui-même (parallélisation propre)

**Parallélisation obligatoire** : envoyer tous les Agent tool calls dans le MÊME message (bloc `<function_calls>` unique multiple invocations), pas séquentiels. Sinon perte du gain temps.

### 3. Consolider les findings

Une fois tous les experts terminés :

- **Dédup** : même `file:line` mentionné par 2+ experts → 1 seule entrée avec mention `[double-flag: <expert1>, <expert2>]` (renforce priorité)
- **Ranger par sévérité** : P0 (union tous experts) → P1 → Quick wins → Déjà correct
- **Cross-refs** : si `security-multitenant` dit "hors scope — invoquer `back-architect`" ET `back-architect` a effectivement flag → linker
- **Contradictions** : rare en PARALLEL (chaque expert reste dans son scope). Si contradiction : escalate en DEBATE mode.

### 4. Format rapport unifié

```
### Multi-Agent Audit — <file/diff>

**Mode** : PARALLEL
**Experts dispatchés** : <liste + models>
**Fichier(s)** : <path> (<X> lignes)

---

#### 🔴 P0 (bloquer)

- `file:line` — <description> — solution
  - Flag par : <expert1>[, <expert2> — double-flag renforce priorité]
  - Source : <docs/... ou scan-secu step X>

#### 🟡 P1 (avant merge)

- `file:line` — <description> — solution
  - Flag par : <expert>

#### 🟢 Quick wins

- ...

#### ✅ Déjà correct (consensus)

- <2-4 points positifs consensus multi-experts>

---

#### 🔀 Cross-refs / délégations

- `<expert1>` a dit "hors scope — invoquer `<expert2>`" — `<expert2>` a effectivement flag `<point>` → consistent
- (Si contradiction repérée : recommander `/multi-agent debate <expert1,expert2> <path>`)

#### 📊 Consolidation

| Sévérité | Count | Experts flag |
|---|---|---|
| P0 | <N> | <experts sources> |
| P1 | <N> | ... |
| Quick wins | <N> | ... |

**Verdict global** : SHIP | NEEDS CHANGES | REJECT
**Action recommandée** :
1. Fixer P0 (deep-dive expert flag si besoin)
2. Adresser P1 avant merge
3. Considérer quick wins si temps
4. Re-lancer `code-reviewer` (couche 5) après fixes pour final gate
```

## Méthode — mode DEBATE

### 1. Contexte

Utiliser quand :
- 2 experts avec verdicts contradictoires observés (ex: audit précédent)
- Décision architecturale trade-off (perf vs lisibilité, refactor vs patch, split A vs B)
- User dit explicitement "debate <expert1>,<expert2> sur X"

### 2. Dispatch

Invoquer les 2 experts **séparément** avec la MÊME question / fichier. Consigne : "Prends position, argumente avec citations file:line, propose ton verdict."

### 3. Round 2 — dialectique

Fournir à chaque expert le verdict de l'autre. Consigne : "L'autre expert dit X. Réfute ou concède, avec sources."

Max 2 rounds — au-delà = décision meta (main context tranche).

### 4. Format DEBATE

```
### Multi-Agent Debate — <question ou fichier>

**Mode** : DEBATE
**Experts** : <expert1> vs <expert2>
**Question / scope** : <contexte>

---

#### Round 1 — Positions initiales

**<expert1>** :
> Verdict : <X>
> Arguments : <1-3 bullets avec file:line>

**<expert2>** :
> Verdict : <Y>
> Arguments : <1-3 bullets avec file:line>

#### Round 2 — Dialectique

**<expert1>** (après lecture du verdict de <expert2>) :
> Concède : <point sur lequel l'autre a raison>
> Maintient : <point sur lequel il tient> + argument renforcé

**<expert2>** (idem) :
> ...

#### Arbitrage (main context)

- Points de consensus : <liste>
- Points de désaccord irréductible : <liste>
- **Décision** : <choix argumenté avec pondération>
- **Trade-off assumé** : <ce qu'on sacrifie et pourquoi>
```

## Anti-patterns refusés

- ❌ **Dispatch séquentiel** en mode PARALLEL — perte gain temps, envoyer tous les Agent en 1 seul message
- ❌ **Dispatch tous les 10 experts sur un fichier trivial** — coût tokens, bruit
- ❌ **Dispatch experts hors scope** (ex: `product-strategist` sur bugfix) — refusera de toute façon
- ❌ **Boucler DEBATE indéfiniment** — max 2 rounds, sinon décision meta
- ❌ **Skip la consolidation** — un rapport unifié dédupliqué, pas 5 rapports collés
- ❌ **Omettre code-reviewer (couche 5) final** — même après multi-agent, le final gate avant commit reste `code-reviewer`

## Format d'invocation user

```bash
# Mode PARALLEL — auto-select experts selon path
/multi-agent app/services/document_service.ts

# Mode PARALLEL — experts explicites
/multi-agent app/services/document_service.ts back-architect,security-multitenant,data-access-reviewer

# Mode DEBATE — 2 experts contradictoires
/multi-agent debate back-architect,security-multitenant app/services/foo.ts

# Diff staged (pas de path)
/multi-agent --staged
```

## Sources

- Cookbook agents (roles/ + stacks/adonisjs/) : `docs/claude-config/experts.md` §4
- Cookbook code-reviewer (couche 5 final gate) : `.claude/agents/stacks/adonisjs/code-reviewer.md`
- Karpathy §2.2 "Sous-agents : déléguer recherche, pas décision" : `docs/lessons.md`
- Dispatch matrix : `.claude/skills/feature/references/dispatch-matrix.md`
