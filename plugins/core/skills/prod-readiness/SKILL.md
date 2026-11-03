---
name: prod-readiness
description: Assess production readiness (score /100 weighted with critical gates) across security, reliability, observability, delivery and data, with P0/P1/P2 actions and effort. Mode --debt adds code health (dependencies, tests, docs, architecture, quality) with trend and roadmap. Triggers when user says "prêt pour prod ?", "audit prod", "prod readiness", "shipper en prod", "on peut lancer ?", "dette technique", "santé du projet".
argument-hint: "[--debt] [--trend] [--roadmap]"
---

# Skill `/prod-readiness`

Diagnostic + score + plan actionable pour amener un projet à la maturité production requise, **avec le plus petit footprint opérationnel approprié**.

## Positionnement dans le cookbook

- **Couche 6 — Production readiness** — après le reviewer final (couche 5, avant `git commit`)
- **Distinct de `/ai-config`** :
  - `/ai-config` = "as-tu bien Claude Code installé ?" (18 standards kit)
  - `/prod-readiness` = "es-tu prêt à shipper en prod ?" (capabilities infra/prod)
- **Distinct de `/pre-pr`** :
  - `/pre-pr` = lint + typecheck + build (technique fichier)
  - `/prod-readiness` = capabilities operationnelles (backup, monitoring, alerting, TLS…)

## Mode `--debt` — santé du code

`/prod-readiness --debt` ajoute au diagnostic la **santé du code** : dépendances, tests, documentation, architecture, qualité, avec impact temporel, tendance (`--trend`) et roadmap par ROI (`--roadmap`). Sécurité et delivery ne sont pas recalculés : ils viennent de la carte de capabilities. Méthode complète : `methodology/tech-debt.md`.

## Ce que ça NE fait PAS (V0)

- Recommande pas de provider spécifique (Sentry vs Datadog vs Rollbar) — ce sera V1 avec catalog `providers/*.yaml` + pricing dated
- Génère pas de config file (Sentry SDK etc.) — ce sera V2
- Ouvre pas de PR — ce sera V2

V0 = **diagnostic + score + action steps génériques**. Assez pour prioriser, sans dette de maintenance pricing.

## Principes canoniques (voir aussi `methodology/`)

1. **Evaluate capabilities before products** — "error monitoring" est une capability, "Sentry" est un produit
2. **Detected ≠ Confirmed** — SDK installé ≠ prod monitoring correct
3. **Free-first + TCO** — préférer capacités existantes, puis free tier, puis managed low-cost (V1)
4. **`DO_NOTHING` explicit** — l'absence de tracing sur un MVP à 2 services n'est pas un gap
5. **Critical gate override** — un score 87 avec `no backup` = plafonné à 60
6. **Confidence obligatoire** — chaque finding tag HIGH/MEDIUM/LOW selon grille déterministe (`methodology/confidence.md`)
7. **Pondération par risque, pas moyenne naïve** — cf `methodology/scoring.md`
8. **Contexte obligatoire** — sans maturity/users/budget, refuser (ou prompt)

## Workflow — 7 phases

```
INPUT (repo + contexte)
   │
   ▼
1. DISCOVERY      — script scan-prod-readiness.sh : signals repo (deps, IaC, workflows, config files)
   │
   ▼
2. CONTEXT        — lire PRODUCT.md OU prompt user (maturity, users, budget, RPO/RTO)
   │
   ▼
3. CAPABILITY MAP — matcher signals aux 5 domaines × N capabilities (voir capabilities/*.yaml)
   │
   ▼
4. GAP ANALYSIS   — capability status : NOT_DETECTED | PARTIAL | COVERED | OVER_COVERED | NOT_APPLICABLE | UNKNOWN
                    Gap severity : CRITICAL | HIGH | MEDIUM | LOW | NONE (en fonction de maturity)
   │
   ▼
5. MATURITY+SCORE — score /100 par domaine + global pondéré
                    Critical gate check : cap score si critical-gates.yaml échoue
   │
   ▼
6. SOLUTIONS      — pour chaque gap actionable, générer action step générique
                    Types : INTEGRATE | CONFIGURE | UPGRADE | REPLACE | REMOVE | OPTIMIZE | DO_NOTHING
   │
   ▼
7. ACTION PLAN    — prioriser P0/P1/P2 selon (Impact × Risk × Confidence) ÷ Effort
                    Sortie MD (report.md template)
```

## Contexte requis

Lire depuis `PRODUCT.md` si présent :
- `maturity` : prototype / MVP / production / enterprise
- `users.current` et `users.expected_12_months`
- `traffic.requests_per_day` (si documenté)
- `budget.monthly` USD
- `availability_target` (%)
- `compliance` : liste (gdpr, soc2, hipaa, pci, none)

Si `PRODUCT.md` absent OU sections manquantes → **prompter user** :

```
Contexte projet manquant. 4 questions pour scorer correctement :

1. Maturity actuelle ? [prototype | MVP | production | enterprise]
2. Users actuels (approx) ?
3. Budget infra/mois ($USD) ?
4. Availability target requis ? [none | 99% | 99.9% | 99.99%]
```

Persister réponses dans `docs/prod-readiness-context.yaml` pour reruns.

## Méthode

### Étape 1 — Lancer scan discovery

```bash
bash scripts/scan-prod-readiness.sh [path]
```

Sortie : JSON stdout listant signals détectés par domaine.

Signals cherchés (V0) :
- `package.json` : deps (sentry, posthog, express-rate-limit, helmet, pg-boss, bull, opentelemetry, …)
- `Dockerfile` + `compose.yaml` : conteneurisation
- `terraform/`, `pulumi/`, `helm/`, `k8s/`, `serverless.yaml`, `wrangler.toml` : IaC
- `.github/workflows/`, `.gitlab-ci.yml`, `.circleci/config.yml` : CI/CD
- `.env.example` : variables ops (SENTRY_DSN, DATABASE_URL, S3_*, REDIS_*, …)
- Config files : `sentry.client.config.ts`, `next.config.js` (headers), `nginx.conf`, `caddy.json`
- `README.md` : sections "Deployment", "Monitoring", "Backup"

### Étape 2 — Lire contexte

- Read `PRODUCT.md` sections context + roadmap
- Read `docs/prod-readiness-context.yaml` si présent
- Sinon → prompt user 4 questions

### Étape 3 — Charger capabilities catalogs

Read `capabilities/*.yaml` (5 domaines V0) :
- `security.yaml` — TLS, auth, secrets, WAF, headers, rate-limit, deps scan
- `reliability.yaml` — backup, restore-testing, HA, retry, circuit-breaker
- `observability.yaml` — logs, metrics, tracing, uptime, error-tracking, alerting
- `delivery.yaml` — CI, CD, rollback, feature-flags, migrations gates
- `data.yaml` — DB, storage, cache, queue, PII handling

Chaque capability YAML :
```yaml
- name: error_tracking
  domain: observability
  maturity_required:
    prototype: optional
    mvp: recommended
    production: required
    enterprise: required
  weight: 8               # sur /10 dans le domaine
  detection_signals:
    - dep: '@sentry/*'
    - dep: 'rollbar'
    - env: 'SENTRY_DSN'
  confirmation_signals:
    - config_file: 'sentry.*.config.*'
    - env_value_nonempty: 'SENTRY_DSN'
```

### Étape 4 — Gap analysis

Pour chaque capability :
- Détecter status via detection_signals du scan
- Confirmer via confirmation_signals (sinon → PARTIAL)
- Ajuster severity selon maturity du projet vs maturity_required
- Tag confidence (voir `methodology/confidence.md`)

### Étape 5 — Score

Formule : voir `methodology/scoring.md`.

```
Domain score = Σ (capability_weight × capability_score) / Σ capability_weight
Global score = Σ (domain_weight × domain_score) / Σ domain_weight

Domain weights (V0) :
  Security          20%
  Reliability       20%
  Observability     15%
  Delivery          15%
  Data              15%
  (Performance      10% — V1)
  (Product          5% — V1 : couplé product-strategist)
  (Cost             5% — V1)
```

Critical gate cap : si `capabilities/critical-gates.yaml` échoue → score plafonné à 60.

### Étape 6 — Générer solutions

Pour chaque gap actionable :
- Si NOT_DETECTED + required → action `INTEGRATE` avec effort estimé (30min à 4h)
- Si PARTIAL + required → action `CONFIGURE`
- Si OVER_COVERED (2+ providers pour même capability) → action `REMOVE` sur le moins-utile
- Si NOT_DETECTED + optional at current maturity → action `DO_NOTHING` avec condition de revisit
- Pas de provider recommandé V0 — recos type "add error tracking (Sentry / Rollbar / etc.)"

### Étape 7 — Action plan

Prioriser :
```
priority_score = (impact × risk_reduction × confidence) / (effort × cost_delta)

P0 : priority_score ≥ 0.8 OU critical_gate failed
P1 : 0.4 ≤ priority_score < 0.8
P2 : 0.1 ≤ priority_score < 0.4
Backlog : priority_score < 0.1 OU maturity_required > current
```

Rendre en MD selon `templates/report.md`.

## Sortie

Fichier : `docs/prod-readiness-report.md` (créé/écrasé)

Sections (voir `templates/report.md`) :
1. Executive summary + score card
2. Score par domaine + jauges texte
3. Critical gaps
4. P0 immediate actions
5. P1 next actions
6. P2 backlog
7. `DO_NOTHING` explicites (avec condition de revisit)
8. `OVER_COVERED` findings
9. Unknowns + assumptions
10. Confidence per finding

## Anti-patterns du skill

- ❌ Recommander Sentry par nom en V0 (V1 avec pricing dated)
- ❌ Skipper contexte (prompt user si absent, jamais assume MVP par défaut)
- ❌ Score 100 sans avoir vérifié critical gates
- ❌ "Add monitoring" tout court — toujours "Add [capability X] (options: [A/B/C]) — effort ~[N]min — because [reason]"
- ❌ Marquer CONFIRMED si juste dep installée sans config file
- ❌ Cacher UNKNOWN sous PARTIAL ou COVERED

## Références

- `capabilities/*.yaml` — 5 domaines catalog
- `methodology/scoring.md` — formule pondérée + critical gate
- `methodology/maturity.md` — 4 niveaux + expected par level
- `methodology/confidence.md` — grille déterministe HIGH/MEDIUM/LOW
- `templates/report.md` — squelette MD sortie
- `scripts/scan-prod-readiness.sh` — discovery bash V0

## Roadmap V1/V2 (backlog)

- **V1** : `providers/*.yaml` avec pricing dated + `_pricing_asof`, TCO computation, JSON output `docs/prod-readiness.json`, recos nommées, capabilities Performance + Cost + Product
- **V2** : action `INTEGRATE` génère fichiers config (Sentry SDK snippet, husky hooks, k8s manifests). Optionnellement ouvre PR draft.
