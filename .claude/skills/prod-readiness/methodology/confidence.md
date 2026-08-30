# Confidence — grille déterministe

Chaque finding (capability status) doit être taggé HIGH / MEDIUM / LOW / UNKNOWN.

**Objectif** : éviter les recos présentées comme certaines alors qu'elles reposent sur des suppositions.

## Grille V0

### HIGH (≥ 90% certitude)

Au moins **3 signaux confirmés** OU au moins **1 signal + config vérifiée end-to-end**.

Exemples :
- Sentry PRESENT si : (`@sentry/*` dans package.json) + (`SENTRY_DSN` dans .env.example) + (`sentry.client.config.ts` existe)
- TLS enforced si : `redirect http → https` détecté dans `next.config.js` OU config nginx OU Cloudflare mode "always use HTTPS"
- Backup DB si : cron dump script OU AWS RDS backup enabled dans Terraform OU managed provider (Supabase, Neon)

### MEDIUM (60-89% certitude)

**1 signal fort** mais non-vérifié end-to-end.

Exemples :
- Sentry MEDIUM si : dep installée mais aucun config file trouvé (peut-être installée mais non-wired)
- Rate limiting MEDIUM si : `express-rate-limit` dep présente mais usage grep 0 (peut-être inutilisée)
- CD MEDIUM si : `.github/workflows/deploy.yml` existe mais on ne peut pas vérifier qu'il tourne

### LOW (30-59% certitude)

**Mention en doc/README uniquement** OU **signal ambigu**.

Exemples :
- Monitoring LOW si : README dit "we use Datadog" mais aucun signal code
- Backup LOW si : commentaire `# TODO: setup backup` sans implémentation

### UNKNOWN (< 30%)

**Aucun signal exploitable**. Ne pas assumer PRESENT ni MISSING → flag rapport.

Exemples :
- Prod environment UNKNOWN si : pas de `.env.production`, pas d'IaC, pas de docs deployment
- Actual traffic UNKNOWN si : PRODUCT.md ne renseigne pas users.current

## Impact sur scoring

```
capability_score_adjusted = capability_score_raw × confidence_multiplier
```

| Confidence | Multiplier |
|---|---|
| HIGH | 1.0 |
| MEDIUM | 0.9 |
| LOW | 0.7 |
| UNKNOWN | (item exclu du calcul + listé dans rapport §Unknowns) |

## Affichage rapport

Chaque finding cite sa confidence :

```
✓ Error tracking — PRESENT (HIGH)
  Evidence:
    - dep: @sentry/nextjs
    - config: sentry.client.config.ts
    - env: SENTRY_DSN in .env.example

⚠ Rate limiting — PARTIAL (MEDIUM)
  Evidence:
    - dep: express-rate-limit
  Missing:
    - No middleware usage found

✗ Uptime monitoring — MISSING (HIGH)
  Evidence:
    - No signal in package.json, IaC, workflows, README
```

## Anti-patterns

- ❌ Marquer HIGH sur dep installée sans config vérifiée
- ❌ Cacher UNKNOWN sous PARTIAL — user doit voir ce qu'on ne sait pas
- ❌ Recommander action P0 basée sur finding LOW — d'abord confirmer
- ❌ Downgrader confidence pour éviter reco embarrassante
