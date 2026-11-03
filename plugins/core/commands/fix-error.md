---
description: Diagnostic + fix d'un message d'erreur (runtime, build, test, CI). Approche 3 étapes : reproduire → root cause → fix ciblé. Refuse patch symptôme.
---

# /fix-error — Diagnostic + fix d'erreur

Traite un message d'erreur (runtime, build, test, CI, lint). Discipline cookbook : **reproduire → root cause → fix ciblé**. Pas de patch symptôme.

## Options

- Aucune : mode standard (le user colle l'erreur ou pointe un log)
- `--deep` : analyse approfondie incluant deps + facteurs environnementaux (node version, env vars, DB schema)
- `--quick` : fix immédiat visible sans diagnostic profond (pour typos, imports manquants, TS types triviaux)
- `--preventive` : après le fix, ajoute une leçon à `docs/lessons.md` §3 ou un test de non-régression

## Méthode — approche 3 étapes

### Étape 1 — Reproduire

**Règle** : ne PAS spéculer sans reproduction (cf `docs/lessons.md` §1.1 "Think Before Coding").

- Runtime error → demander stack trace COMPLET, pas résumé
- Build error → coller output complet, pas juste "build fails"
- Test fail → coller sortie test + config test + snapshot si applicable
- CI fail → `gh run view <run-id> --log` OU URL du run

Si reproduction impossible localement (dépend d'env spécifique) : le dire, demander accès ou aide user.

### Étape 2 — Root cause

Identifier la CAUSE, pas le SYMPTÔME.

Ordre d'investigation :

1. **Lire le message exact** — pas paraphraser. Erreur cite un fichier:ligne ? Lire ce fichier:ligne.
2. **Tracer le stack** — remonter le call tree jusqu'à l'origine (souvent ligne 3-5 du stack, pas ligne 1 qui est un handler générique)
3. **Grep patterns similaires** — le bug existe peut-être ailleurs dans la même forme
4. **Vérifier changements récents** — `git log -p -- <file>` sur les derniers commits, corrélation temporelle
5. **Env / config** (mode `--deep`) — `.env`, `package.json` versions, node version, DB schema drift

**Anti-pattern refusé** : "Ajouter try/catch pour swallow l'erreur" — ce n'est pas un fix, c'est du blame-hiding. Utiliser `swallow()` helper uniquement pour fire-and-forget documenté.

### Étape 3 — Fix ciblé

Surgical change (cf `docs/lessons.md` §1.3) :

- Ne modifier QUE la ligne / bloc causal
- Match le style existant même si suboptimal
- Nettoyer uniquement les imports/vars devenus orphelins par ta modif
- Pas de refactor "tant que j'y suis"

### Étape 4 — Vérifier

- Reproduire le scénario qui a fail → doit passer maintenant
- Tests existants → doivent rester verts
- Type-check → `npm run typecheck`
- Lint → `npm run lint`
- Build → `npm run build` (si change touche imports/exports)

Ne pas dire "fixed" sans avoir re-testé le scénario exact.

### Étape 5 — Preventive (mode `--preventive`)

Si le bug est un PATTERN qui pourrait réapparaître :

- Ajouter une entrée à `docs/lessons.md` §3 (leçons accumulées)
- OU ajouter un anti-pattern à `docs/anti-patterns.md`
- OU ajouter un test de non-régression
- OU ajouter une règle grep au `scan-secu.sh` si détectable statiquement

Cf `docs/lessons.md` §2.4 "Boucle d'auto-amélioration".

## Anti-patterns refusés

- ❌ **Spéculer sans stack trace** — demander la trace exacte
- ❌ **Patch symptôme** — try/catch swallow, workaround qui masque
- ❌ **"Marche sur ma machine"** — reproduire dans l'env exact où ça fail (CI, staging, prod dev tools)
- ❌ **Fix + refactor massif dans le même commit** — surgical seulement
- ❌ **Dire "fixed" sans re-tester** — vérification obligatoire (cf `docs/lessons.md` §2.3)

## Format de sortie

```
### Fix-error — diagnostic

**Erreur** : "<message court>"
**Type** : runtime | build | test | CI | lint | typecheck
**File:line** : <si mentionné dans l'erreur>

**Étape 1 — Reproduction** :
- Commande utilisée : `<cmd>`
- Reproduit : ✅ oui | ❌ non (raison : <...>)

**Étape 2 — Root cause** :
> <1-2 phrases sur la vraie cause, pas le symptôme>
- File:line responsable : `<file:line>`
- Cause : <invariant violé, race condition, config drift, etc.>
- Introduit par : <commit sha si identifiable via git log>

**Étape 3 — Fix proposé** :
- Files touchés : <liste>
- Diff résumé : <1-2 lignes>
- Impact : <ce qui change de comportement, ce qui reste identique>

**Étape 4 — Vérification** :
- [ ] Scénario original re-testé et passe
- [ ] Tests existants verts
- [ ] Typecheck OK
- [ ] Lint OK

**Étape 5 — Preventive** (si `--preventive`) :
- [ ] Leçon ajoutée à `docs/lessons.md` §3
- [ ] Test de non-régression ajouté : `<path>`

**Action** :
- Confirmer approche avant Edit
- Si diagnostic incertain : demander plus d'info user avant de coder
```

## Sources

- `docs/lessons.md` §1.1 Think Before Coding, §1.3 Surgical Changes, §2.3 Vérification, §2.4 Auto-amélioration
- `docs/anti-patterns.md` §Sécurité (swallow pattern)
- Cookbook `back-architect` / `security-multitenant` / `data-access-reviewer` selon domain touché par le fix
