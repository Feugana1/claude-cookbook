# lessons.md — Leçons apprises + discipline session

> **Destinataire** : toi/team + tous les subagents (chargé par plusieurs).
> **Format** : discipline générale + leçons projet spécifiques. Enrichi après chaque bug/régression/correction utilisateur.

---

## 1. Discipline de session (Karpathy 4 disciplines)

### 1.1 Think Before Coding

Avant d'éditer, **comprendre** :
- Lire le code environnant (dépendances, callers)
- Reproduire le bug avant de proposer un fix
- Identifier la source de vérité (spec, test, doc)

Sans repro : hypothèses = spéculation. **Reproduire → diagnostiquer → fixer**.

### 1.2 Small Focused Changes

- Un commit = un intent
- Diff ≤ 200L de préférence
- Refactor et feature = commits séparés

### 1.3 Surgical Changes

- Modifier le minimum
- Pas de "tant qu'à faire" (nettoyer imports, renommer variables, etc.)
- Le nettoyage vit dans son propre commit `chore: cleanup imports`

### 1.4 Verify Before Completion

- Compiler / typecheck / tests AVANT de dire "c'est fait"
- Si UI : lancer l'app et voir la feature marcher
- Si CLI : exécuter la commande

---

## 2. Sous-agents : déléguer recherche, pas décision

**Bon usage** :
- Dispatcher un sous-agent pour explorer un sujet précis (path, pattern, symbol)
- Récupérer sa synthèse
- **Toi** décide de l'action

**Mauvais usage** :
- "Sous-agent, fais tout" — dilue la responsabilité, hallucinations combinées
- Sous-agent qui invoque un autre sous-agent — profondeur explose, contexte perdu

---

## 3. Vérification avant clôture

Avant de dire "task done" :
- [ ] Compilation OK
- [ ] Tests verts (unit + integration si applicable)
- [ ] Lint sans warning nouveau
- [ ] Le comportement demandé est observable (pas juste "le code est là")
- [ ] Aucun fichier oublié dans le staging

---

## 4. Boucle auto-amélioration

Quand user corrige ton approche → **écrire la leçon ici** (§5) pour ne pas répéter.

Quand tu corriges un bug non trivial → **ajouter le pattern à `anti-patterns.md`** pour le catcher automatiquement la prochaine fois.

---

## 5. Leçons projet — enrichir au fil de l'eau

Format : date (ISO) — leçon en 1 ligne — cross-ref (fichier, PR, incident).

### 2026-XX-XX — `<Titre leçon>`

**Contexte** : `<qu'est-ce qui s'est passé>`
**Erreur** : `<ce qui a été fait à tort>`
**Correct** : `<ce qu'il fallait faire>`
**Cross-ref** : `<PR #N, incident YYYY-MM-DD, doc>`

---

## 6. Anti-cérémonie

Ce projet **ne fait pas** :
- Semver strict
- CHANGELOG.md manuel (git log suffit)
- Releases GitHub tagged
- Docs Wiki externes

Ce projet **fait** :
- Conventional Commits (parseable par tooling)
- README + CLAUDE.md + AGENTS.md + PRODUCT.md à jour
- Anti-patterns catalogués dans `docs/anti-patterns.md`
- Tests là où le comportement est non trivial (pas 100% coverage forcé)

---

## Références

- `docs/anti-patterns.md` — patterns interdits catalogués
- `docs/architecture.md` — architecture globale
- `AGENTS.md` — playbook opérationnel Claude Code
- Cookbook `docs/lessons.md` (générique) — discipline transverse
