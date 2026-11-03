---
description: Analyse perf application — bottlenecks (CPU/IO/DB/network), Core Web Vitals, propositions optim rankées par ROI. Délègue agent `performance` pour deep-dive.
---

# /analyze-performance — Analyse perf + propositions optim

Analyse performances application (backend + frontend + DB + réseau) et propose optimisations rankées par ROI (gain × probabilité vs coût dev).

**Distinct de `performance` agent** : `/analyze-performance` = skill user-invoqué qui lance analyse. `performance` agent = expert Claude délégué pour deep-dive spécifique.

## Options

- `--scope backend|frontend|db|network|all` (défaut all)
- `--profile <file>` — importe profil Chrome DevTools / Node --prof
- `--baseline` — enregistre baseline pour compare post-optim
- `--target <metric>` — cible SLO ("LCP < 2.5s", "P95 < 200ms")

## Méthode

### 1. Charger contexte

Lire :
- Config app (nombre workers, pool DB, cache TTL)
- Logs récents (slow queries, errors)
- `CLAUDE.md` §10 perf DB si présent
- Profil s'il est fourni

### 2. Détecter signaux

**Backend** :
- Slow queries (DB EXPLAIN si accessible)
- N+1 : grep patterns `.load(` après `.query()`
- Sync blocking calls dans event loop (Node)
- Missing indexes (comparé aux queries fréquentes)

**Frontend** :
- Bundle size (`npm run build` output)
- Images non-optimisées (grep `.jpg`, `.png` sans variant WebP)
- Fonts non-subsettées
- CSS/JS blocking dans `<head>`

**DB** :
- Pool config vs traffic
- Missing indexes sur FK
- Full table scans (`EXPLAIN`)
- Long-running queries (slow query log)

**Réseau** :
- Missing CDN pour statiques
- Cache-Control / ETag absents
- Compression désactivée
- HTTP/1.1 (vs HTTP/2)

### 3. Ranker par ROI

Pour chaque optim :

| Facteur | Poids |
|---|---|
| Gain user chiffré | ms saved, % conversion, cost saved |
| Probabilité de gain réel | mesuré vs supposé |
| Coût dev (heures) | implém + test + monitoring |
| Risque introduction bug | complexité change |

**ROI = (gain × prob) / (coût × risque)**

### 4. Proposer optim phasées

Ranked P0/P1/quick wins :

- **P0** : ROI élevé + gain > 30% + risque faible
- **P1** : ROI moyen ou gain 10-30%
- **Quick wins** : coût trivial, gain marginal (bonus)

Chaque optim : mesure attendue (chiffré), fichiers touchés, coût estimé.

### 5. Anti-recos

Lister ce qu'il NE FAUT PAS faire :
- Optim tentante mais mauvais ROI
- Optim avec effets secondaires (cache invalidation, breaking API)
- Micro-optim boucle serrée qui court 10x/jour

### 6. Déléguer deep-dive

Si scope large ou expert deep requis :
- Invoquer agent `performance` (opus) pour analyse approfondie
- `/multi-agent <path> performance,back-architect` pour cross-perspective

## Format de sortie

```
### Performance Analysis — <scope>

**Sources chargées** : <config, logs, docs perf projet>

**Métriques baseline** :
- Backend : P50 <Xms> | P95 <Yms> | P99 <Zms>
- Frontend : LCP <Xs> | INP <Yms> | CLS <Z>
- DB : slowest query <Xms>, N+1: yes/no
- Bundle : <YMB>

**Signaux détectés** :
| Signal | Localisation | Sévérité |
|---|---|---|
| Slow query > 500ms | `app/services/X.ts:42` | High |
| N+1 pattern | `app/controllers/Y.ts:88` | Medium |
| Bundle > 500KB | `dist/main.js` | Medium |
| ... | ... | ... |

**Optimisations rankées** :

**🔴 P0 (gain > 30%)** :
1. <optim> — mesure attendue : LCP -Xs
   - Files : <liste>
   - Coût : <heures>
   - Risque : Bas
2. ...

**🟡 P1 (gain 10-30%)** :
- ...

**🟢 Quick wins (coût trivial)** :
- Enable Brotli compression → -20% payload size
- Add `loading="lazy"` sur images below fold → -50% initial load

**⚫ Anti-recos** :
- ❌ Migrer à microservices "pour la perf" — pas de mesure justifiant
- ❌ Cache Redis sur tout — invalidation cost > benefit sur données volatiles
- ❌ Refactor massif ORM — profiler d'abord queries réelles

**Deep-dive recommandé** :
- Invoquer agent `performance` pour analyse SQL EXPLAIN sur queries top-5 slow
- `/multi-agent app/services/heavy_service.ts performance,back-architect` pour perspective structure + perf

**Plan validation post-optim** :
1. Baseline commit ce rapport
2. Implém P0 items
3. Re-mesure identique setup
4. Delta chiffré confirmé avant merge
```

## Anti-patterns refusés

- ❌ Recommandations sans mesure ("c'est probablement plus rapide")
- ❌ Optim sur code qui court 10 fois/jour (mauvais ROI)
- ❌ Sur-cache (cache invalidation = 2ème hardest problem in CS)
- ❌ Refactor massif sans profil
- ❌ Ignorer perf mobile (assume desktop)

## Sources

- `CLAUDE.md` §10 perf DB (si projet AdonisJS)
- Cookbook agent `performance` — deep-dive expert
- Web Vitals : https://web.dev/vitals/
- RAIL model : https://web.dev/rail/
- `scripts/scan-secu.d/step-29-db-fk-indexes.sh` (indexes FK check)
