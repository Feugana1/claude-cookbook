---
description: Analyse dépendances projet — matrice modules, détection cycles, fan-in/fan-out, health architecturale. Sortie visuelle ASCII + reco refactor si cycles ou couplage excessif.
---

# /analyze-dependencies — Analyse dépendances + santé architecturale

Analyse dépendances internes (imports entre modules) + externes (npm packages) pour détecter :
- **Cycles** (A → B → A) — anti-pattern architectural
- **Couplage excessif** (fan-out > 20 sur 1 module)
- **God modules** (fan-in > 30, importé partout)
- **Dead code** (fan-in = 0, jamais importé)
- **Deps outdated** (major versions retard)

## Options

- `--circular` — détecte seulement cycles (rapide)
- `--visual` — output ASCII matrix / graph
- `--depth N` — profondeur analyse (défaut 3)
- `--focus <path>` — focus 1 module ou dir
- `--external` — inclut npm deps (pas juste internes)

## Méthode

### 1. Cartographier imports internes

```bash
# Pour projets AdonisJS / Node TS
grep -rn "^import.*from '#" app/ --include="*.ts" > /tmp/imports.txt
grep -rn "^import.*from '\./\|^import.*from '\.\./" app/ --include="*.ts" >> /tmp/imports.txt

# Parser : (from_file, to_module)
```

Construire graphe orienté modules → dépendances.

### 2. Métriques par module

Pour chaque module :

| Métrique | Description | Seuil alerte |
|---|---|---|
| **Fan-in** | Combien de modules importent celui-ci | > 30 = god module |
| **Fan-out** | Combien de modules ce module importe | > 20 = couplage haut |
| **Cycle membership** | Fait partie d'un cycle | Oui = anti-pattern |
| **Depth** | Profondeur transitive max | > 5 = archi trop stratifiée |

### 3. Détecter cycles (algo DFS)

Chercher cycles orientés :
- A → B → A (cycle 2)
- A → B → C → A (cycle 3)
- ...

Chaque cycle = anti-pattern à casser (extraire interface, déplacer code, DI inversion).

### 4. Détecter god modules

Fan-in élevé + fan-out élevé = module central qui devrait être décomposé.

### 5. Détecter dead code

Fan-in = 0 :
- Vraiment mort ? (grep `require`, `dynamic import`, `test`)
- OU export public utilisé externe ? (npm module, API endpoint)

### 6. Deps externes (si `--external`)

```bash
npm outdated                    # major versions retard
npm audit                       # CVE
npx depcheck                    # deps installés mais non-importés
```

## Format de sortie

```
### Dependency Analysis — <projet ou focus>

**Sources chargées** : imports scan, package.json, tsconfig paths

**Scope analysé** :
- Modules internes : <count>
- Deps externes : <count>
- Profondeur max transitive : <N>

---

#### 🔴 Cycles détectés (P0)

Aucun | <N> cycles :

1. `A.ts` → `B.ts` → `A.ts` (cycle direct)
   - Fix : extraire interface commune `IShared` dans `types/`
2. `X.ts` → `Y.ts` → `Z.ts` → `X.ts` (cycle 3)
   - Fix : inverser dépendance via DI (Y devrait pas importer Z)

#### 🟡 God modules (fan-in > 30)

| Module | Fan-in | Fan-out | Recommandation |
|---|---|---|---|
| `app/services/user_service.ts` | 45 | 18 | Split par domaine (profile, auth, prefs) |
| `app/helpers/utils.ts` | 62 | 3 | Split par thème (date, string, math) |

#### 🟢 High coupling (fan-out > 20)

| Module | Fan-out | Recommandation |
|---|---|---|
| `app/controllers/dashboard.ts` | 28 | Extraire sub-services agrégateurs |

#### ⚫ Dead code (fan-in = 0)

- `app/helpers/legacy_formatter.ts` — vérifier avant delete (grep dynamique)
- `app/services/deprecated_service.ts` — dernière modif <date>, à supprimer ?

#### 📦 Deps externes

- Outdated major : <count> (`npm outdated`)
- CVE : <count critical, count high> (`npm audit`)
- Unused (installés mais non-importés) : <count> (`depcheck`)

#### 📊 Matrice ASCII (si --visual)

```
                app/    app/         app/
                ctrl/   svc/         models/
app/ctrl/       [-]     [XX]         [X]
app/svc/        [X]     [-]          [XXX]
app/models/     [-]     [-]          [X]
```

**Recommandations phasées** :
- Phase 1 (immédiat) : casser les <N> cycles
- Phase 2 (court terme) : décomposer god modules
- Phase 3 (moyen terme) : réduire couplage haut

**Anti-recos** :
- ❌ Refactor tout d'un coup — approche incrémentale
- ❌ Extraire interface pour interface — YAGNI si 1 seul implémenteur
```

## Anti-patterns architecturaux surveillés

- **Cycle** → toujours P0
- **God module** (fan-in > 30) → P1 split
- **Chain trop long** (depth > 5) → aplatir
- **Bidirectional binding** (A ↔ B) → même mécanisme que cycle
- **Sky hooks** (deps injectées globales) → DI explicite

## Sources

- Karpathy 4 §1.2 Simplicity First (pas d'abstraction pour interface single-user)
- `docs/lessons.md` §3 patterns génériques
- `scripts/scan-secu.d/step-11-duplication.sh` (complément détection duplication)
- npm : `depcheck`, `madge` (visualisation graph), `dependency-cruiser`
