# Maturity — 4 niveaux + expected capabilities

## Les 4 niveaux

### prototype

- **Users** : 0-10 (soi-même, team, alpha testers)
- **SLA** : aucun
- **Focus** : itération rapide, apprentissage
- **Critical** : aucun capability n'est required, seuls quelques-uns recommended

### MVP

- **Users** : 10-1000
- **SLA** : best effort (peut-être 95%)
- **Focus** : product-market fit, valider valeur
- **Critical** : backup DB, TLS, auth basique, error tracking basique

### production

- **Users** : 1k-100k
- **SLA** : 99% à 99.9%
- **Focus** : reliability + observability + delivery pipeline
- **Critical** : critical gates full + monitoring + alerting + rollback + CI/CD mature

### enterprise

- **Users** : 100k+
- **SLA** : 99.9%+
- **Focus** : compliance, HA multi-region, on-call, DR tested
- **Critical** : tout + compliance (SOC2/HIPAA/etc.) + chaos testing + runbooks

## Mapping capability × maturity

Chaque capability YAML déclare son `maturity_required` :

```yaml
maturity_required:
  prototype: optional | recommended | required
  mvp: optional | recommended | required
  production: optional | recommended | required
  enterprise: optional | recommended | required
```

Règles :
- `optional` = capability absente → capability_score = 100 (pas un gap)
- `recommended` = capability absente → capability_score = 60 (pénalité modérée)
- `required` = capability absente → capability_score = 0 (gap plein)

## Progression typique

```
prototype (optional partout)
    ↓ 500 users, product-market fit approche
MVP (backup + TLS + auth + error tracking required, monitoring recommended)
    ↓ 5k users, first paying customers
production (observability required, uptime SLA, CI/CD mature, alerting)
    ↓ 100k users, B2B contracts
enterprise (compliance, HA, DR, on-call rotation, runbooks)
```

## Détection automatique maturity (fallback)

Si contexte manquant ET pas de PRODUCT.md, heuristique de fallback (marker LOW confidence) :

| Signal détecté | Maturity présumée |
|---|---|
| README mentionne "MVP" ou "prototype" | prototype |
| README mentionne "beta" | MVP |
| README mentionne "production", "SaaS", "customers" | production |
| README mentionne "enterprise", "SOC2", "SLA 99.9%" | enterprise |
| CI/CD présent + Dockerfile + deps count > 30 | MVP minimum |
| Terraform + monitoring configuré + multiple env | production |

**Toujours prompt user pour confirmer** avant d'utiliser la présomption.

## Alerte user en cas de mismatch

Si maturity_declared ≠ maturity_detected (heuristique), afficher :

```
⚠ Maturity mismatch :
  User declared : MVP
  Signals suggest : production (CI/CD + Terraform + 3 envs + monitoring configured)

Confirmez ? [y = MVP correct, n = utiliser production]
```
