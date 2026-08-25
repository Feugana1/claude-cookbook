---
description: Vérifie précision d'une affirmation (technique, architecture, feature) contre codebase + docs projet. Anti-hallucination. Sortie CORRECT / INCORRECT / PARTIEL / INCONNU + preuves file:line.
---

# /check-fact — Vérification claim vs codebase

Anti-hallucination. Vérifie qu'une affirmation matche la réalité du code / doc du projet. Utile pour :
- Onboarding : "on utilise Redis, non ?" — vérifier
- Documentation : claims dans README à valider
- LLM output review : sortie autre agent à fact-check
- Refactor : "personne n'appelle cette fonction" — vérifier

## Usage

```bash
/check-fact "L'app utilise Redis pour la session"
/check-fact "Le controller documents_controller.ts n'a pas de tests"
/check-fact "JWT est utilisé, pas de sessions"
/check-fact "SubdomainMiddleware.globalPassthrough couvre /health"
```

## Méthode

### Ordre de vérification (fiabilité décroissante)

1. **Code actuel** (source de vérité ultime)
2. `package.json` / `pubspec.yaml` / `Cargo.toml` (deps déclarées)
3. Config files (`.env.example`, `config/`, `start/`)
4. `README.md` + `docs/` (peut être drifté du code)
5. Issues / PR / discussions GitHub (contexte historique)

### Verdicts possibles

- ✅ **CORRECT** — code confirme exactement l'affirmation
- ❌ **INCORRECT** — code contredit l'affirmation
- ⚠ **PARTIELLEMENT CORRECT** — parties vraies, parties fausses/nuancées
- ❓ **IMPOSSIBLE À DÉTERMINER** — pas assez d'info dans le codebase

### Preuves obligatoires

Chaque verdict doit citer :
- **File:line** du code / doc qui prouve
- **Extrait code** pertinent
- **Note** : pourquoi ça prouve (ou infirme)

### Nuances à surfacer

- Différence entre "utilisé actuellement" vs "installé/importé mais mort"
- Différence entre "prod" vs "dev/test env"
- Différence entre "feature flag ON par défaut" vs "actif chez tous les users"
- Différence entre "convention" vs "enforcement"

## Format de sortie

```
### Fact-check

**Affirmation** : "<claim exact>"

**Verdict** : ✅ CORRECT | ❌ INCORRECT | ⚠ PARTIEL | ❓ INCONNU

**Preuves** :

Preuve 1 :
- **File:line** : `<path:line>`
- **Extrait** :
  ```
  <code exact>
  ```
- **Analyse** : <pourquoi ça prouve / infirme>

Preuve 2 :
- ...

**Détails** :
- Si INCORRECT : voici ce qui est réellement vrai
  > <vraie situation avec source>
- Si PARTIEL : voici les nuances
  > <ce qui est vrai + ce qui est faux + why>
- Si INCONNU : voici ce qu'il faudrait vérifier
  > <sources à consulter, questions à poser user, tests à écrire>

**Sources consultées** :
- <liste fichiers grepped / read>

**Confidence** : Haute | Moyenne | Basse
- Haute : preuve directe code + tests
- Moyenne : preuve doc/config, code cohérent
- Basse : inférence indirecte, drift possible entre doc et code
```

## Exemples

### Exemple 1 — CORRECT

```
Affirmation : "L'app utilise Neon Postgres avec pool min=0 (autosuspend)"
Verdict : ✅ CORRECT
Preuves :
- config/database.ts:12 : `pool: { min: 0, max: 10 }`
- .env.example:5 : `DATABASE_URL=postgresql://neondb...`
- docs/database-neon.md:8 : "Neon serverless, pool min=0, autosuspend 5min"
Confidence : Haute (3 sources cohérentes)
```

### Exemple 2 — INCORRECT

```
Affirmation : "Il n'y a aucun test dans le projet"
Verdict : ❌ INCORRECT
Preuves :
- tests/functional/auth.spec.ts:1 : test file présent
- tests/unit/user_service.spec.ts:1 : test file présent
- package.json:15 : `"test": "node ace test"`
Détails : 12 fichiers tests trouvés, coverage estimé ~40%
Confidence : Haute
```

### Exemple 3 — PARTIEL

```
Affirmation : "L'auth utilise JWT"
Verdict : ⚠ PARTIEL
Preuves :
- app/middleware/auth_middleware.ts:23 : session-based (`ctx.session.get('userId')`)
- app/services/api_token_service.ts:5 : JWT utilisé POUR API tokens (endpoints /api/*)
Détails :
- Web auth : sessions (pas JWT)
- API auth : JWT (routes /api/*)
- Nuance : "JWT" est vrai pour /api mais faux pour web app.
Confidence : Haute
```

### Exemple 4 — INCONNU

```
Affirmation : "Le taux de churn est de 5%"
Verdict : ❓ IMPOSSIBLE À DÉTERMINER
Preuves : Aucune. Codebase ne contient pas de métrique churn.
Détails : Il faudrait :
- Query DB analytics (Mixpanel / Amplitude / interne)
- Consulter dashboard business (pas dans codebase)
- Demander au product owner
Confidence : N/A
```

## Anti-patterns

- ❌ Verdict sans preuve file:line
- ❌ "Probablement correct" — trancher CORRECT/INCORRECT/PARTIEL/INCONNU
- ❌ Confondre "installé" et "utilisé activement"
- ❌ Ignorer nuances env (dev vs prod, feature flags)
- ❌ Skip sources multiples si doc + code peuvent diverger

## Sources

- Code (source de vérité ultime)
- `package.json` / config files
- `docs/` / `README.md`
- Issues + PR discussions GitHub
- Tests (contrat comportemental)
