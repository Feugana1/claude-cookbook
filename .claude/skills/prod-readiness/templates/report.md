# Production Readiness Report

**Project** : `<project-name>`
**Date** : `<YYYY-MM-DD>`
**Maturity** : `<prototype | MVP | production | enterprise>`
**Context confidence** : `<HIGH | MEDIUM | LOW>`

---

## Executive summary

`<2-3 sentences : verdict + top 3 blockers>`

---

## Score card

```
╭──────────────────────────────────────────────────────────────╮
│                 PRODUCTION READINESS                         │
│                                                              │
│                        <SCORE> / 100                         │
│                        <LEVEL>                               │
│                                                              │
│ Security           <XX>  <bar>                               │
│ Reliability        <XX>  <bar>                               │
│ Observability      <XX>  <bar>                               │
│ Delivery           <XX>  <bar>                               │
│ Data               <XX>  <bar>                               │
╰──────────────────────────────────────────────────────────────╯

🔴 <N> critical gaps
🟠 <N> important gaps
🟡 <N> improvements
```

`<bar>` = 20 chars, `█` pour chaque 5% (ex : 76 → `███████████████░░░░░`).

**Level scale** :
- 90-100 EXCELLENT
- 75-89 GOOD
- 60-74 ACCEPTABLE
- 40-59 RISKY
- 0-39 NOT_READY

---

## Critical gates

`<Pour chaque critical gate : status ✓ PASS ou 🔴 FAIL avec evidence>`

| Gate | Status | Reason |
|---|---|---|
| DB backup | ✓ PASS / 🔴 FAIL | `<evidence>` |
| TLS enforced | ✓ PASS / 🔴 FAIL | `<evidence>` |
| Authentication | ✓ PASS / 🔴 FAIL | `<evidence>` |
| Error tracking | ✓ PASS / 🔴 FAIL | `<evidence>` |

`<Si au moins 1 FAIL>` : Score plafonné à 60. **Traiter les gates avant toute autre action**.

---

## Coverage par domaine

### Security — `<XX>/100`

| Capability | Status | Confidence | Evidence |
|---|---|---|---|
| TLS enforced | ✓ COVERED / ⚠ PARTIAL / ✗ NOT_DETECTED | HIGH/MEDIUM/LOW | `<signals>` |
| Authentication | | | |
| Secrets management | | | |
| Security headers | | | |
| Rate limiting | | | |
| WAF | | | |
| Dependency scanning | | | |
| Input validation | | | |

### Reliability — `<XX>/100`

`<idem>`

### Observability — `<XX>/100`

`<idem>`

### Delivery — `<XX>/100`

`<idem>`

### Data — `<XX>/100`

`<idem>`

---

## P0 — Immediate actions

`<Pour chaque P0>` :

### 1. `<Titre action>` — `<INTEGRATE | CONFIGURE | UPGRADE | REPLACE | REMOVE>`

- **Capability** : `<name>`
- **Current** : `<status + evidence>`
- **Gap** : `<what's missing>`
- **Recommendation** : `<generic action + options>`
- **Effort** : `<15min | 1h | 4h | 1d>`
- **Cost delta** : `<$0-X/month>` (confidence: LOW/MEDIUM/HIGH)
- **Priority score** : `<X.X>` (impact × risk × confidence / effort × cost)

**Options** :
- `<option A>` — free tier suffisant si `<condition>`
- `<option B>` — managed low-cost si `<condition>`
- `<option C>` — open-source si `<condition + team op capacity>`

**Implementation steps** :
1. `<step>`
2. `<step>`
3. `<verify>`

---

## P1 — Next actions

`<idem format>`

---

## P2 — Backlog

`<idem format, moins détaillé>`

---

## DO_NOTHING findings

`<Capabilities non-détectées mais correctes pour la maturity actuelle. Éviter overengineering.>`

| Capability | Reason | Revisit when |
|---|---|---|
| Distributed tracing | Pas requis à MVP + 2 services actuels | > 5 services OR > 100k req/day |
| Multi-region HA | Pas requis à MVP | Enterprise maturity OR compliance SOC2 |

---

## OVER_COVERED findings

`<Redondances détectées — capabilities avec 2+ providers. Signal gaspillage.>`

| Capability | Providers détectés | Recommandation |
|---|---|---|
| Logs | CloudWatch + Loki | Consolider vers `<X>`, économie estimée `$Y/month` |

---

## Unknowns et assumptions

`<Ce qu'on n'a pas pu vérifier — force user à confirmer>`

- ❓ Production environment : aucun `.env.production` ni IaC détecté
- ❓ Actual traffic : PRODUCT.md ne renseigne pas `users.current`
- ❓ Backup restore test : aucun script/doc détecté

**Impact** : `<Ces unknowns peuvent modifier le score de ±5 à ±15 points>`.

---

## Cost impact (V0 estimation)

**V0** : pas de pricing par provider hardcodé. Recos type "add capability X (options: Y/Z)".

**V1** : catalog `providers/*.yaml` avec `_pricing_asof` daté produira estimation détaillée.

---

## Sources

- `scripts/scan-prod-readiness.sh` output (JSON)
- `PRODUCT.md` sections `<listées>`
- `docs/prod-readiness-context.yaml` (si présent)
- Prompts user answered `<datetime>`

---

## Roadmap architecture

### Now (P0 items above)
`<résumé>`

### Next (P1 items above)
`<résumé>`

### Later (P2 + backlog)
`<résumé>`

### Not needed at current maturity
`<liste condensée DO_NOTHING findings>`
