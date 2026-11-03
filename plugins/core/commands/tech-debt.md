---
description: Dashboard santé projet — score global, dette technique quantifiée par catégorie (deps / tests / docs / archi / sécu / qualité), tendance, plan amélioration priorisé par ROI temporel.
---

# /tech-debt — Dashboard santé + plan amélioration

Analyse dette technique du projet et produit dashboard santé avec plan d'amélioration priorisé. Impact concret : temps ralentissement dev / support / onboarding.

## Options

- `--focus deps|tests|docs|arch|security|quality` — analyse ciblée
- `--trend` — comparer avec baseline précédente (`docs/tech-debt-baseline.json`)
- `--roadmap` — génère roadmap phasée `docs/tech-debt-roadmap.md`

## Méthode

### 1. Score par catégorie (0-100)

#### Deps (poids 15%)
```bash
npm outdated --json  # major versions retard
npm audit --json     # CVE
npx depcheck         # unused deps
```
- Score : 100 - (outdated_major × 5) - (CVE_critical × 20) - (CVE_high × 10)

#### Tests (poids 20%)
```bash
# Coverage
npm test -- --coverage
# Ratio tests/code
find app -name '*.ts' | wc -l
find tests -name '*.spec.ts' | wc -l
```
- Score : coverage% pondéré par criticité modules (auth, paiement → 90% requis)

#### Documentation (poids 10%)
- `README.md` présent + à jour (last commit)
- `docs/` couvre architecture + setup + conventions
- Ratio public API documented / total

#### Architecture (poids 20%)
- Dépendances circulaires (via `/analyze-dependencies`)
- Fichiers > limites `check-file-sizes.js` (§14 300/400/800)
- Duplication code (jscpd)
- Score : 100 - (cycles × 10) - (violations_size × 3) - duplication%

#### Sécurité (poids 25%)
- `scan-secu.sh` résultats : T1 FAIL bloquant
- Sécurité headers présents (Shield / Helmet)
- Secrets scan (gitleaks) clean

#### Qualité (poids 10%)
- Lint warnings (eslint)
- TypeScript strict mode
- Fichiers avec `TODO`, `FIXME`, `HACK` count

### 2. Score global pondéré

Score global = Σ (score_catégorie × poids)

### 3. Impact temporel estimé

Convertir dette en temps perdu :
- Ralentissement nouveau dev : X min / feature
- Ralentissement bugfix : X min / bug
- Ralentissement code review : X min / PR
- Onboarding : X jours / nouveau membre

### 4. Tendance (si `--trend`)

Comparer avec `docs/tech-debt-baseline.json` :
- Δ score par catégorie (dernier check → maintenant)
- Rate d'amélioration ou dégradation
- Éléments améliorés / nouveaux dettes

### 5. Roadmap priorisée (si `--roadmap`)

Ranked par ROI = (gain × probabilité) / (coût × risque)

- **Quick wins** : coût faible, gain élevé → Phase 1
- **Structural** : coût moyen, gain durable → Phase 2
- **Long-term** : coût élevé, gain stratégique → Phase 3

## Format de sortie

```
### Dashboard Santé Projet — <date>

**Sources chargées** : npm audit, npm outdated, coverage report, scan-secu output, /analyze-dependencies

**Score global** : XX/100  (▲ +N depuis last check | ▼ -M)

**Scores par catégorie** :
- 📦 Fraîcheur deps       : ████████░░ XX%  (outdated: N major, CVE: X critical / Y high)
- 🧪 Coverage tests        : ██████░░░░ XX%  (cible: 80%, critique: 90%)
- 📚 Documentation         : ███░░░░░░░ XX%  (README, docs/architecture.md, API docs)
- 🏗️ Architecture          : ██████░░░░ XX%  (cycles: N, files-over-limit: M, duplication: X%)
- 🔒 Sécurité              : ███████░░░ XX%  (T1 FAIL: N, headers: OK/KO, secrets: clean/leak)
- ✨ Qualité code          : ███████░░░ XX%  (lint warnings: N, TODO count: M)

**Tendance 30 jours** :
- Score global : <before> → <now> (Δ +/-<N>)
- Améliorés : <count items> ✅
- Nouvelle dette : <count items> ⚠️
- Résolus : <count items> 🎉

**Impact temporel de la dette** :
- Ralentissement dev feature : +XX% (base : X h)
- Bugfix : +XX%
- Code review : +XX%
- Onboarding nouveau membre : +XX jours
- **Total cumulé** : équivalent XX heures/semaine perdues

**Top 5 dettes prioritaires** :
1. [P0] <catégorie> : <problème>
   - Impact : <estimation>
   - Effort : <heures>
   - ROI : Élevé
2. [P0] ...
3. [P1] ...
4. [P1] ...
5. [P2] ...

**Roadmap phasée** :

Phase 1 — Quick wins (1 semaine)
- [ ] Fix N CVE via npm audit fix
- [ ] Delete N deps unused (depcheck)
- [ ] Add missing headers Shield config

Phase 2 — Structural (1 mois)
- [ ] Boost coverage modules critiques (auth: 60% → 90%)
- [ ] Casser N cycles imports (/analyze-dependencies)
- [ ] Split N files over limite §14

Phase 3 — Long-term (trimestre)
- [ ] Migrer deps majors X, Y, Z
- [ ] Refactor god module `<path>` (fan-in > 30)
- [ ] Documentation architecture cible

**Anti-recos** :
- ❌ Refactor tout d'un coup — approche incrémentale
- ❌ Chase 100% coverage dogmatique
- ❌ Fix cosmétique (TODO cleanup) sans impact réel

**Baseline enregistrée** : `docs/tech-debt-baseline.json` (si --trend futur)
**Roadmap générée** : `docs/tech-debt-roadmap.md` (si --roadmap)
```

## Anti-patterns

- ❌ Score global sans détail par catégorie
- ❌ Recommandations sans impact temporel chiffré
- ❌ Roadmap sans priorité ROI
- ❌ Ignorer tendance (trajectoire > snapshot)
- ❌ Refactor massif comme unique reco

## Sources

- `scripts/scan-secu.sh` (sécurité)
- `scripts/check-file-sizes.js` (archi limits)
- `npm audit`, `npm outdated`, `depcheck`
- Coverage tools (nyc, c8, vitest)
- Cookbook `/analyze-dependencies` (cycles + fan-in/out)
- Cookbook agents `architect` / `security` / `qa` pour deep-dive
