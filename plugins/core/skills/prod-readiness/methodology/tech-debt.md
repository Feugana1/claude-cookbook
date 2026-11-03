# Mode `--debt` — santé du code et dette technique

Référence du mode `--debt` de `/prod-readiness`. Complète la carte de capabilities (sécurité, fiabilité, observabilité, delivery, données) avec ce qu'elle ne couvre pas : la **santé du code**. Sécurité et delivery ne sont **pas recalculés** ici : reprendre leur score de la carte de capabilities (et `bash scan-secu.sh` pour le détail sécurité).

## Catégories (score 0-100 chacune)

Adapter les commandes à la toolchain du projet (`package.json`, `Makefile`, `pyproject.toml`, `go.mod`…). Une catégorie sans outil disponible est notée `UNKNOWN` (jamais inventée) et exclue de la moyenne.

| Catégorie | Poids | Mesures | Score indicatif |
|---|---|---|---|
| **Dépendances** | 20 | majeures en retard (`npm outdated`, `pip list --outdated`…), CVE (`npm audit`, `pip-audit`…), dépendances inutilisées | 100 − 5 × majeures en retard − 20 × CVE critique − 10 × CVE haute |
| **Tests** | 30 | couverture, ratio fichiers de test / fichiers de code, couverture des modules critiques (auth, paiement, données) | couverture pondérée par criticité (≥ 90 % attendu sur le critique) |
| **Documentation** | 15 | README à jour, doc d'architecture et de setup, API publique documentée | part couverte |
| **Architecture** | 25 | cycles de dépendances, fichiers au-dessus des limites du projet (ratchet de taille s'il existe), duplication (jscpd…), fan-in/fan-out excessif | 100 − 10 × cycles − 3 × fichiers hors limite − % duplication |
| **Qualité** | 10 | warnings du linter, mode strict du typage, `TODO` / `FIXME` / `HACK` | selon la densité |

**Score `--debt`** = moyenne pondérée des catégories connues.

## Impact temporel

Convertir la dette en temps perdu, même approximatif : ralentissement par feature, par bugfix, par review, par onboarding (jours / nouveau membre). Une reco sans impact estimé n'est pas priorisable.

## Tendance (`--trend`)

Comparer à `docs/tech-debt-baseline.json` (créée au premier passage) : Δ par catégorie, éléments améliorés, nouvelle dette, résolus. La trajectoire compte plus que le snapshot.

## Roadmap (`--roadmap`)

Classer par ROI = (gain × probabilité) / (coût × risque) et écrire `docs/tech-debt-roadmap.md` :
- **Phase 1 — quick wins** (≈ 1 semaine) : correctifs de CVE, suppression de deps inutiles
- **Phase 2 — structurel** (≈ 1 mois) : tests des modules critiques, casser les cycles, splitter les fichiers hors limite
- **Phase 3 — long terme** (trimestre) : migrations de majeures, refonte d'un module « god », doc d'architecture cible

## Format de sortie

```
### Santé du code — <date>
**Score `--debt`** : XX/100 (▲/▼ vs baseline) — **Prod-readiness** : XX/100 (rappel)

| Catégorie | Score | Détail |
| Dépendances / Tests / Documentation / Architecture / Qualité | … | … |

**Impact temporel** : feature +X % · bugfix +X % · review +X % · onboarding +X j
**Top 5 dettes** : [P0|P1|P2] <catégorie> — problème — impact — effort — ROI
**Roadmap phasée** (si --roadmap) : phases 1 / 2 / 3
```

## Refusé

- ❌ Score global sans détail par catégorie
- ❌ Recommandation sans impact estimé ni ROI
- ❌ Refactor massif comme unique reco, ou course dogmatique à 100 % de couverture
- ❌ Nettoyage cosmétique (`TODO`) sans effet réel
- ❌ Recalculer la sécurité ou le delivery ici : ils viennent de la carte de capabilities
