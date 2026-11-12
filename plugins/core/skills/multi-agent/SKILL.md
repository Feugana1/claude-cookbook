---
name: multi-agent
description: Dispatch parallèle de N experts (agents installés) sur un même fichier/diff → rapport unifié consolidé. Pattern multi-perspective (architecture + sécurité + données + linter en //) OU adversarial (debate 2 experts contradictoires). Use when user says "audit complet ce fichier", "multi-perspective review", "3 experts sur ce diff", "/multi-agent <path> <experts>".
---

# /multi-agent — Dispatch parallèle N experts + synthèse

Lance plusieurs experts (agents installés) **en parallèle** sur le même fichier / diff, puis synthétise leurs findings en un seul rapport dédupliqué et rangé par sévérité.

Deux modes :
- **PARALLEL** (défaut) : N experts indépendants, perspectives complémentaires — synthèse union
- **DEBATE** : 2 experts avec verdicts potentiellement opposés — synthèse dialectique + arbitrage

## When to invoke

- Audit exhaustif d'un fichier critique (nouveau service metier, controller sensible, migration risquée)
- Diff PR volumineux touchant plusieurs domaines (back + front + DB + i18n)
- Décision architecturale contradictoire (ex: l'architect propose un split A, le reviewer sécurité préfère la structure B)
- Le user tape `/multi-agent <path> <expert1,expert2,...>` OU `/multi-agent debate <expert1,expert2> <path>`

## When NOT to invoke

- Fichier trivial (< 100L, pas de logique métier) — utiliser un seul expert cible
- Bugfix ponctuel — action directe ou expert unique (`analyzer`)
- Nouvelle feature — utiliser `/feature` (qui dispatch déjà les experts en interne)

## Experts disponibles

Les experts sont **découverts**, pas codés en dur : lister `.claude/agents/**/*.md` et lire le frontmatter (`name`, `description`, `model`). Chaque `description` dit quand l'expert s'applique. Les experts projet-spécifiques installés localement sont dispatchables au même titre que ceux du cookbook.

Si le projet a un `docs/dispatch-matrix.md` (livré par un pack de stack), il fait foi pour le mapping path → experts.

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

Choisir les experts par correspondance entre le path/diff et la `description` de chaque agent installé (ou via `docs/dispatch-matrix.md` s'il existe). Règle de dosage : 2 à 4 experts complémentaires (structure, sécurité, données, linter), un reviewer final si le diff est non trivial. Diff cross-domain : tous les experts pertinents en parallèle.

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
- **Cross-refs** : si un expert dit "hors scope — invoquer X" ET X a effectivement flag → linker
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
4. Re-lancer le reviewer final (couche 5) après les fixes
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
- ❌ **Dispatcher tous les experts sur un fichier trivial** — coût tokens, bruit
- ❌ **Dispatch experts hors scope** (ex: `product-strategist` sur bugfix) — refusera de toute façon
- ❌ **Boucler DEBATE indéfiniment** — max 2 rounds, sinon décision meta
- ❌ **Skip la consolidation** — un rapport unifié dédupliqué, pas 5 rapports collés
- ❌ **Omettre le reviewer final (couche 5)** — même après multi-agent, le final gate avant commit reste le reviewer du projet

## Format d'invocation user

```bash
# Mode PARALLEL — experts choisis selon le path
/multi-agent <path>

# Mode PARALLEL — experts explicites
/multi-agent <path> <expert1,expert2,expert3>

# Mode DEBATE — 2 experts contradictoires
/multi-agent debate <expert1,expert2> <path>

# Diff staged (pas de path)
/multi-agent --staged
```

## Sources

- Catalogue des agents : `docs/claude-config/experts.md`
- Karpathy §2.2 « Sous-agents : déléguer recherche, pas décision » : `docs/lessons.md`
- Mapping path → experts d'une stack : `docs/dispatch-matrix.md` (fourni par le pack, si installé)
