# Feature Plan Template (unifié spec + plan)

> **RÈGLE ABSOLUE** : Toute feature/bugfix non-triviale DOIT avoir un fichier `docs/features/<nom>.md` basé sur ce template.
> **1 seul doc par feature** — il capture le pourquoi (spec), la roadmap (plan), l'état d'avancement (vivant), et la qualité de livraison (checklist). Mis à jour à chaque commit majeur.

---

## Pourquoi ce format unifié

L'ancienne approche "spec longue + plan exhaustif inline" produisait des docs de 2000+ lignes avec code dupliqué. Ce format vise **~200L max** en gardant la valeur (décisions tracées + verify gates + completeness checklist) et en jetant ce qui pèse (code inline, re-narration, checkboxes per substep — le commit-id suffit comme signal "done").

## Quand l'utiliser

- **Feature** : remplir toutes les sections AVANT d'écrire la première ligne de code
- **Bugfix non-trivial** (≥2 fichiers ou ≥50 lignes ou touche `app/middleware/migrations/routes`) : remplir sections 1, 2, 3, 5, 6
- **Bugfix trivial** (1 fichier, < 50 lignes, pas critique) : pas de plan, commit direct avec message descriptif
- **Refactor** : remplir avec focus sur §4 non-goals + §7 risques

## Où mettre le doc

- Si une **doc mère existe** pour le domaine (ex: `docs/workflows.md`, `docs/accounting.md`) : enrichir cette doc plutôt que créer un satellite. Plan → section dans la doc mère.
- Sinon : créer `docs/features/<nom-kebab>.md`.
- À la fin (feature livrée) : entrée datée dans `docs/dev-changelog.md`, le satellite reste pour archive.

---

## Template (copier-coller intégral, ~200L max au final)

```markdown
# Feature: <Titre court>

**Status** : `planning` | `in_progress` | `blocked` | `done`
**Last update** : YYYY-MM-DD
**Branche** : feat-xxx
**Spec mère** (si applicable) : [`docs/<domain>.md`](../<domain>.md)

---

## 1. Why (10 lignes max)

- **Problem** : qui a la friction, dans quel parcours ?
- **Pain mesuré** : ticket support, churn, métrique, conversation client
- **Value delivered** : gain concret côté user (en 1 phrase)

## 2. Decisions actées (table)

| # | Décision | Why | Alternatives rejetées |
|---|----------|-----|----------------------|
| D1 | … | … | … |
| D2 | … | … | … |

> Toute décision non-triviale doit avoir son entrée. Si on change d'avis pendant l'exécution, on MAJ la table (pas un nouveau doc).

## 3. Architecture (30 lignes max)

**Data model** (TS interfaces inline si critiques) :
\`\`\`typescript
// app/types/<feature>_schema.ts
export interface XBody { … }
\`\`\`

**Endpoints** :
| Method | URL | Action | Validator |
|--------|-----|--------|-----------|
| GET | /x | list | — |
| POST | /x | create | xValidator |

**Files map** (toutes les modifs anticipées) :
| Lot | File | Action |
|-----|------|--------|
| 1 | `app/types/x_schema.ts` | CRÉER |
| 1 | `app/validators/x.ts` | CRÉER |
| 2 | `app/controllers/x_controller.ts` | MODIFIER |
| … | … | … |

## 4. Non-goals (5 lignes)

- ❌ Ce qu'on NE fait PAS dans cette phase (à scope creep-block)
- ❌ …

## 5. Lots — état vivant

> Chaque lot = unité commitable indépendante. Mis à jour à chaque commit.

### Lot 1: <nom>
- **Files** : `path/a.ts`, `path/b.ts`
- **Status** : ✅ commit `b89d0493` (date)
- **Verify** : `node ace build --ignore-ts-errors` → ✅ OK

### Lot 2: <nom>
- **Files** : `path/c.ts`
- **Status** : 🟡 in_progress
- **Verify (à exécuter)** : `curl -sw '%{http_code}' http://localhost:3333/x` → attendu 200

### Lot 3: <nom>
- **Files** : …
- **Status** : 🔲 not started

## 6. Quality completeness (12 dimensions — checklist gate avant merge)

Cocher chaque dimension. Si une dimension est non-applicable, écrire `N/A — <raison>`.

- [ ] **Tests unit** zone critique (NF525 / paiement / sécu multi-tenant) — `node ace test`
- [ ] **IDOR multi-tenant** : toutes queries ont `.where('userId', effectiveUserId)`
- [ ] **Soft-delete** : `.whereNull('deletedAt')` sur tables qui en ont (Documents notamment)
- [ ] **Dark mode** : vérifié visuellement sur chaque écran modifié
- [ ] **Mobile responsive** : breakpoints sm/md/lg testés
- [ ] **i18n FR + EN** : 0 string hardcoded user-facing
- [ ] **Sentry instrumenté** : 5xx + exceptions critiques (PaymentException, AuthorizationException, jobs)
- [ ] **Performance** : ≤ 5 queries paralleles par handler, 0 N+1 (preload partout)
- [ ] **A11y** : focus visible, aria-label sur boutons icon-only, contraste WCAG AA
- [ ] **Anti-patterns** : grep `auth.user.id` / `@click in @include` / `{{{ JSON }}}` / `border border-stone-200` etc. → zéro
- [ ] **Build prod OK** : `node ace build --ignore-ts-errors` → success
- [ ] **Curl golden path** : status 200 sur le parcours principal après auth

## 7. Risques actifs

| R | Risque | Probabilité | Impact | Mitigation |
|---|--------|-------------|--------|------------|
| R1 | … | M | É | … |
| R2 | … | F | M | … |

## 8. Success criteria (Definition of Done)

**Côté user** :
1. Le user peut <action 1> en <N clics/secondes>
2. <Action 2 mesurable>
3. <Métrique business cible>

**Côté code** :
1. Tous les lots commitable indépendamment ✅
2. Quality completeness §6 = 12/12 cochés
3. `scan-secu.sh` → 0 FAIL (étapes touchées)
4. Pas de régression sur features adjacentes (smoke test manuel)

---

## Journal (append-only — optionnel mais utile pour gros sprints)

- **YYYY-MM-DD** : décision DX prise pendant l'exécution / blocage levé / pivot mineur
```

---

## Workflow recommandé

1. **Avant code** : remplir §1-4 (why, decisions, architecture, non-goals) + §6 completeness liste + §8 success criteria. Ces 5 sections sont la "spec".
2. **Pendant code** : MAJ §5 lots (status + commit-id) à chaque commit majeur. C'est le "plan vivant".
3. **Avant merge** : cocher §6 (12 dimensions). Si une dimension fail → fix avant merge, pas après.
4. **Après merge** : entrée dans `docs/dev-changelog.md`. Le doc feature reste pour archive (utile pour onboarding + audit).

## Anti-patterns à éviter

- ❌ Créer 2 docs (spec + plan) — fusionner en 1
- ❌ Copier-coller code complet inline dans le doc — l'agent l'écrit au moment de l'exécution
- ❌ Checkbox par sub-step — le commit-id est le signal "done"
- ❌ Re-narration du contexte à chaque task — §1-3 fait le job une fois
- ❌ Skip §6 quality completeness — c'est le seul vrai gate avant merge
- ❌ Doc > 300 lignes — si ça déborde, c'est un signal de scope trop large (splitter en sub-features)

---

## Fichiers de plans actifs

> **Règle** : une fois livrée, la feature reste pour archive + entrée dans [`docs/dev-changelog.md`](dev-changelog.md). Si doc mère existe, on l'enrichit au lieu de créer un satellite.

| Feature/Fix                                    | Fichier                                                                            | Status                |
| ---------------------------------------------- | ---------------------------------------------------------------------------------- | --------------------- |
| Gallery preset unification (Phase 1)           | [features/gallery-preset-unification.md](features/gallery-preset-unification.md)   | 🟡 in_progress (Lots 1-3 livrés) |
| Feature Management Admin (flags + surfaces)    | [features/feature-management-admin.md](features/feature-management-admin.md)       | 🔲 planning |
| Google Drive import (defaults + batch durable) | [features/google-drive-import.md](features/google-drive-import.md)                 | 🔲 planning |
| Contextual messaging per service/gallery       | [features/portal.md](features/portal.md)                                           | 🔲 planning |
| Subscription cancellation review flow          | [features/subscriptions.md](features/subscriptions.md)                             | 🔲 planning |
| Storage Add-Ons (packs stockage extensibles)   | [features/storage-addons.md](features/storage-addons.md)                           | 🔲 planning |
| Cloudflare credits strategy 12 mois            | [features/cloudflare-credits-strategy.md](features/cloudflare-credits-strategy.md) | 🟡 in_progress |
| Facture électronique France (SuperPDP)         | [features/facture-electronique-france.md](features/facture-electronique-france.md) | 🟡 in_progress (Phase 0 livrée 2026-05-23) |

> S7-04 (uploads résilients) et S7-02 (upload mobile) ont été livrés 2026-05-23. Voir [`docs/roadmap.md`](roadmap.md) pour le backlog actuel.

> Specs Shop Revenue Engine (Phases 0-6) et Booking Conversion Engine (B0-B5) **livrées** (2026-04-21). Source de vérité consolidée : [`docs/boutique-booking-guide.md`](boutique-booking-guide.md).

---

_Dernière mise à jour : 2026-05-31 — refonte template format unifié (spec + plan + completeness en 1 doc, ~200L max au lieu de 2561L spec+plan séparés)_
