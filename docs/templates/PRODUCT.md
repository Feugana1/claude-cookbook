# PRODUCT.md — Vision produit

> **Destinataire** : `product-strategist` subagent (couche 0 strategic gate) + toi/team.
> **Format** : direct, factuel, sans marketing. Utilisé pour challenger différenciation de chaque nouvelle feature.

---

## 1. Problème résolu

**Un paragraphe max** : quel problème utilisateur ce produit résout ? Pas "on aide les gens à…", mais "aujourd'hui X galère parce que Y, on résout ça en faisant Z".

Exemple à remplacer :
> Les indépendants en France perdent 4h/semaine à jongler entre 5 outils pour facturer + suivre paiements + gérer TVA. On unifie tout dans une interface qui respecte la loi anti-fraude (NF525).

---

## 2. Utilisateurs cibles

- **Persona principal** : `<qui, taille marché, où les toucher>`
- **Persona secondaire** : `<qui, quand pertinent>`
- **PAS notre cible** : `<qui NE l'est pas — protéger le focus>`

---

## 3. Différenciation

**7 questions canoniques** (le `product-strategist` les pose à chaque feature) :

1. **Problème user** : ce produit résout quel problème concret, non résolu ailleurs ?
2. **Benchmark concurrents** : qui fait ça déjà, comment, quelles limites ?
3. **Différenciation** : notre angle unique — pas "on le fait mieux" mais "on le fait autrement".
4. **Alignement produit** : cette feature sert-elle la vision globale ou est-ce un side-quest ?
5. **Test 60s** : un user comprend-il la valeur en 60 secondes sur la page d'accueil ?
6. **Simplifie/ajoute** : est-ce que ça simplifie l'existant ou ajoute une couche ?
7. **Anti-références** : qu'est-ce qu'on refuse de faire (limites intentionnelles) ?

**Nos réponses actuelles** :

1. `<problème résolu>`
2. `<3-5 concurrents trackés + leurs faiblesses>`
3. `<notre angle unique, en 1 phrase>`
4. `<vision produit en 1 phrase>`
5. `<accroche 60s>`
6. `<par défaut on simplifie ; features qui ajoutent doivent se justifier>`
7. `<liste des non-goals — features qu'on refuse volontairement>`

---

## 4. Non-goals (features qu'on refuse)

Liste explicite de ce qu'on ne fait PAS et pourquoi. Protège le focus produit.

- ❌ `<feature X>` — raison : dilue positionnement / hors cible / concurrent le fait déjà en gratuit / etc.
- ❌ `<feature Y>` — raison : …
- ❌ `<feature Z>` — raison : …

---

## 5. Roadmap thématique

Pas de dates strictes, mais des thèmes ordonnés :

| Phase | Thème | Motivation |
|---|---|---|
| Now | `<thème actuel>` | `<pourquoi maintenant>` |
| Next | `<prochain>` | `<pourquoi ensuite>` |
| Later | `<après>` | `<condition d'activation>` |

---

## 6. Métriques nord

Comment on mesure qu'on gagne ?

- **Metric principale** : `<ex : nombre d'utilisateurs qui facturent au moins 1x/mois>`
- **Anti-metrics** (à surveiller) : `<ex : churn, temps moyen création facture, taux support>`

---

## 7. Benchmark concurrents

Voir `docs/competitive-benchmark/` (une fiche par concurrent tracké).

Format fiche : force, faiblesse, notre angle vs eux.

---

## Références

- `docs/vision.md` (si présent — vision long terme)
- `docs/roadmap.md` (si présent — priorisation détaillée)
- `docs/competitive-benchmark/` (fiches concurrents)
- Agent `product-strategist` : `.claude/agents/roles/product-strategist.md`
