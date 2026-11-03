# Scoring — formule pondérée + critical gate

## Score global

```
Global score = Σ (domain_weight × domain_score) / Σ domain_weight
```

Domain weights (V0) :

| Domaine | Weight |
|---|---|
| Security | 20% |
| Reliability | 20% |
| Observability | 15% |
| Delivery | 15% |
| Data | 15% |
| (Performance) | 10% (V1) |
| (Cost) | 5% (V1) |

Total V0 = 85% (les 15% Performance+Cost+Product en V1).

## Score par domaine

```
domain_score = Σ (capability_weight × capability_score_normalized) / Σ capability_weight

Où :
  capability_weight ∈ [1, 10]  (voir capabilities/*.yaml)
  capability_score_normalized ∈ [0, 100]
```

Score par capability :

| Status | Score |
|---|---|
| COVERED | 100 |
| OVER_COVERED | 90 (redondance = léger malus, signale gaspillage) |
| PARTIAL | 50 |
| NOT_DETECTED + required_at_current_maturity | 0 |
| NOT_DETECTED + optional_at_current_maturity | 100 (pas un gap) |
| NOT_DETECTED + recommended_at_current_maturity | 60 (pénalité modérée) |
| NOT_APPLICABLE | ignoré du calcul |
| UNKNOWN | ignoré du calcul + flag rapport |

Ajustement confidence :
- HIGH : score inchangé
- MEDIUM : score × 0.9
- LOW : score × 0.7

## Critical gate — override

Si l'un des critical gates (voir `capabilities/critical-gates.yaml`) est `FAIL` :

```
global_score_final = min(global_score_raw, 60)
```

Cap à 60 = "GOOD" impossible sans les fondamentaux. Force l'user à voir le blocker.

Critical gates V0 (4) :
- `db_backup_exists` — DB de prod a un mécanisme de backup (managed OU cron dump)
- `tls_enforced` — HTTPS forced (redirect HTTP→HTTPS) OU serverless auto
- `auth_on_prod_routes` — routes prod protégées par middleware auth (sinon marker `//PUBLIC` explicite)
- `error_monitoring_prod` — agrégateur d'erreurs prod (pas juste console.error)

Extension : ajouter capability avec `critical_gate: true` dans son YAML.

## Interprétation score

| Score | Niveau | Signification |
|---|---|---|
| 90-100 | EXCELLENT | Prêt production, over-engineering possible à surveiller |
| 75-89 | GOOD | Prêt production avec quelques P1 à traiter |
| 60-74 | ACCEPTABLE | Prêt MVP, gaps P1 avant scale |
| 40-59 | RISKY | Ship possible mais dette immédiate |
| 0-39 | NOT_READY | Critical gates à traiter avant ship |

## Formule priorité action

Chaque action a une priority_score :

```
priority_score = (impact × risk_reduction × confidence) / (effort_hours × (1 + cost_delta_monthly / 50))
```

Où :
- `impact` ∈ [1, 5] — 5 = user-facing outage possible, 1 = optimisation marginale
- `risk_reduction` ∈ [1, 5] — 5 = élimine risque catastrophique, 1 = réduit friction
- `confidence` ∈ [0.3, 1.0] — LOW=0.3, MEDIUM=0.6, HIGH=1.0
- `effort_hours` — estimation en heures (min 0.25)
- `cost_delta_monthly` — coût mensuel additionnel USD (0 pour free)

Rangement :
- P0 : `priority_score ≥ 5.0` OU critical_gate fail
- P1 : `2.0 ≤ score < 5.0`
- P2 : `0.5 ≤ score < 2.0`
- Backlog : `score < 0.5` OU pas requis à la maturity actuelle

## Exemples

**Exemple 1 — MVP à 500 users, sans backup DB** :
- capability : `db_backup_exists` — CRITICAL GATE FAIL
- global_score_raw = 78
- global_score_final = 60 (capped)
- Verdict : ACCEPTABLE + gate rouge → P0 action

**Exemple 2 — Production à 50k users, tracing absent** :
- capability : `distributed_tracing` — NOT_DETECTED
- maturity_required.production = "recommended" (pas "required")
- capability_score = 60 (pénalité modérée, pas 0)
- pas critical gate
- Verdict : gap MEDIUM, P2 (revisit if > 5 services)

**Exemple 3 — Prototype à 10 users, uptime monitoring absent** :
- capability : `uptime_monitoring` — NOT_DETECTED
- maturity_required.prototype = "optional"
- capability_score = 100 (pas un gap)
- Verdict : DO_NOTHING avec condition "revisit when maturity → MVP"
