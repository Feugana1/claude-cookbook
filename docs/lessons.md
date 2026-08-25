# Leçons & Discipline d'exécution

> Source unique des **règles de discipline méta** et des **patterns de raisonnement** projet.
> Lue automatiquement par les sessions Claude (référencée par CLAUDE.md §17).
>
> **Règle d'ajout** : toute correction utilisateur récurrente, tout pattern d'erreur découvert en review,
> doit être ajouté ici dans la section appropriée. Pas de duplication avec `docs/anti-patterns.md`
> (qui couvre les patterns *code* — celui-ci couvre les patterns *process / méta*).
>
> Les exemples ci-dessous sont **génériques**. Chaque projet ajoute ses propres leçons datées avec référence commit/PR pour trace.

---

## 1. Discipline d'exécution (Karpathy 4)

Quatre principes méta qui s'appliquent en complément des règles techniques de CLAUDE.md.
Seuil d'application : tâche > 5 min ou touchant > 2 fichiers.

### 1.1 Think Before Coding — clarifier avant d'implémenter

**Règle** : ne jamais spéculer silencieusement. Si une ambiguïté existe (interprétation, cause d'un bug, scope d'une feature), nommer les options et demander.

**Why** : la spéculation prématurée coûte des heures d'investigation dans des directions fausses. Demander le stack trace / le payload / la config exacte au départ raccourcit d'un ordre de grandeur.

**How** :
- Avant de proposer une cause à un bug : demander le payload/stack trace/log exact si pas fourni
- Avant d'implémenter une feature ambiguë : lister 2-3 interprétations et choisir avec le user
- Si une décision a un trade-off non-trivial (perf vs lisibilité, refacto vs patch), le surfacer plutôt que trancher silencieusement

### 1.2 Simplicity First — code minimum qui résout le problème

**Règle** : pas de feature non demandée, pas d'abstraction pour usage unique, pas de "configurabilité future", pas de gestion d'erreur pour scénarios impossibles.

**Why** : les abstractions prématurées (services à 1 caller, helpers utilisés une fois) alourdissent le grep et la lecture. La dette conceptuelle est plus coûteuse que la duplication apparente.

**How** :
- 3 lignes similaires : laisser les 3 lignes, pas de helper. Helper seulement à 5+ ou si pattern explicite ailleurs
- Demander "qu'est-ce qui casse si je supprime ce code ?" avant d'ajouter
- Pas de feature flag/backwards-compat shim quand on peut juste changer le code

### 1.3 Surgical Changes — toucher uniquement ce qui est nécessaire

**Règle** : chaque ligne modifiée doit tracer directement à la demande user. Pas de "tant que j'y suis" sur du code adjacent. Match le style existant même si on ferait différemment.

**Why** : les bugfixes qui ratissent large créent des diffs illisibles, masquent les vraies modifs en review, et introduisent des régressions.

**How** :
- Bugfix = corriger UNIQUEMENT le bug rapporté. Si on remarque autre chose, le mentionner sans corriger
- Ne pas reformatter, renommer des vars adjacentes, ou "améliorer" des commentaires non liés
- Nettoyer SEULEMENT les imports/vars que ses propres modifs ont rendus orphelins
- Préserver le code mort pré-existant sauf demande explicite

### 1.4 Goal-Driven Execution — critère de succès vérifiable

**Règle** : avant d'implémenter, formuler le critère de succès comme un test ou une commande qui passe/échoue. Boucler jusqu'à ce que le critère soit vert.

**Why** : "ça marche" sans définition claire = revisits à répétition. Le build seul ne teste rien fonctionnellement.

**How** :
- "Ajouter validation" → "le validator rejette `{email: 'foo'}` et accepte `{email: 'a@b.c'}`"
- "Fix le bug" → reproduire le bug d'abord (curl, screenshot, requête SQL), puis fixer, puis re-tester
- "Refactor X" → tests existants verts avant ET après
- Features UI : tester le golden path en navigateur avant de dire "done"
- Si je ne peux pas tester (pas d'accès staging, pas de compte test), le dire explicitement plutôt que prétendre que c'est fini

---

## 2. Orchestration agentic (LLM workflow)

Règles qui s'appliquent au **process** de travail des sessions Claude, pas au code.

### 2.1 Plan mode par défaut

Passer en mode plan dès qu'au moins une condition est vraie :
- Tâche à ≥ 3 étapes
- Décision architecturale (split, nouveau service, nouvelle table)
- Touche ≥ 2 fichiers existants
- Migration DB ou changement de contrat API/route

Si quelque chose dévie du plan en cours d'exécution : **arrêter et replanifier**, ne pas pousser le delta.

### 2.2 Sous-agents : déléguer la recherche, pas la décision

**Déléguer** : exploration codebase, grep multi-pattern, audit parallèle de plusieurs fichiers, lecture de gros docs.
**Ne PAS déléguer** : choix d'implémentation, écriture de code production, validation de critère métier.
**Pourquoi** : garde le contexte principal propre + parallélise la recherche. Les décisions doivent rester traçables dans la session principale.

### 2.3 Vérification avant clôture

Aucune tâche n'est "terminée" sans preuve fonctionnelle. Un build vert ne suffit pas.
Preuves acceptées : `curl` + status code attendu, screenshot navigateur du golden path, sortie de test, logs lus après reproduction du scénario.
Si la preuve est inaccessible (pas d'accès prod/staging), **le dire explicitement** au lieu de marquer comme terminé.

### 2.4 Boucle d'auto-amélioration

Après **toute correction utilisateur** sur une approche / un pattern / une décision :
1. Identifier la règle sous-jacente
2. Ajouter une entrée dans ce fichier §3 (Leçons accumulées) ou §4 (Anti-patterns process)
3. Si le pattern est purement *code*, l'ajouter à `docs/anti-patterns.md` à la place

Sans cette étape, la même erreur réapparaît à la session suivante.

---

## 3. Leçons accumulées (patterns génériques)

### 3.1 scan-secu — signal sémantique généraliste, jamais regex nom

Toute étape scan-secu doit détecter LA CLASSE de faille (signal sémantique), pas les instances connues (regex nom de route, whitelist filename).

**Why** : whitelist par nom fichier est fragile — nouveaux sites legit apparaissent et fail le scan sans justification. Regex nom rate le pattern quand renommé.

**Pattern canonique** :
1. Grep signal (ex: `getSignedUrl(..., 'Nh')` avec N≥2, ou `.password =` mutation)
2. Contexte via `sed -n "$((line-5)),${line}p"` pour lire N lignes avant match
3. Skip via commentaire `canonical-skip:<class> <raison>` dans contexte
4. Awk pour parse method-scope quand la vérification exige un scope de fonction

Nouveau site legit = ajouter commentaire `canonical-skip:<rule> <raison>` sur ligne match, PAS modifier le scan.

### 3.2 Migrations — pattern obligatoire (AdonisJS + Knex)

Toujours utiliser `hasTable` + `createTable` dans les nouvelles migrations AdonisJS. **Ne jamais** utiliser `createTableIfNotExists`.

**Why** : Knex génère un `CREATE TABLE IF NOT EXISTS` qui ne fonctionne pas correctement quand des `alterTable` ou indexes suivent dans le même `up()`. Warning Knex confirme le problème en prod.

**Pattern** :
```typescript
async up() {
  const exists = await this.schema.hasTable(this.tableName)
  if (exists) return

  await this.schema.createTable(this.tableName, (table) => {
    // colonnes + indexes INLINE ici, pas dans un alterTable séparé
  })
}
```

Ne pas modifier les anciennes migrations déjà appliquées (risque inutile).

---

## 4. Anti-patterns process

Patterns d'erreur **dans la façon de travailler** (pas dans le code — ces derniers sont dans `docs/anti-patterns.md`).

| Anti-pattern | Solution |
|---|---|
| Implémenter sans plan quand >3 étapes | Passer en mode plan (cf §2.1) |
| Déléguer la décision finale à un sous-agent | Sous-agent fait la recherche, la décision reste dans la session principale (cf §2.2) |
| Marquer "terminé" sur la base d'un build vert seul | Exiger une preuve fonctionnelle (cf §2.3) |
| Spéculer sur la cause d'un bug sans demander le stack trace | Demander la trace exacte avant de proposer une cause (cf §1.1) |
| Ratisser large sur un bugfix ("tant que j'y suis") | Surgical changes — uniquement le bug rapporté (cf §1.3) |
| Ajouter un helper pour 3 occurrences | Seuil = 5+ ou pattern explicite ailleurs (cf §1.2) |
| Ne pas capturer une correction utilisateur en leçon | Ajouter §3 ou §4 immédiatement (cf §2.4) |
| Conclure « pas un doublon » sur une distinction *technique* | Juger la redondance du point de vue **usage** : deux écrans qui répondent au même besoin mental de l'utilisateur SONT un doublon, même si l'un est read-only et l'autre CRUD. Vérifier l'app réelle, pas que le code. |
| Ajouter mécaniquement une nouvelle section à un écran de config déjà dense | Avant tout add-feature UI : (1) compter les sections visibles ; (2) si > 4, proposer refactor (accordion/tabs) AVANT d'ajouter ; (3) invoquer `/ux-review <page>`. Cf CLAUDE.md §17.6 density gate. |
| Implémenter une reco "expert" sans auditer l'infra existante | Avant d'implémenter une recommandation générique d'advisor, **toujours grep le codebase pour la feature mentionnée**. Si infra existe : vérifier qu'elle couvre le besoin, ajuster/améliorer plutôt que recréer. Senior dev = push back justifié, pas approval blind. |

---

## 5. Ajout de leçons projet-specific

Ce fichier est le **template générique** livré par le cookbook. Chaque projet doit :

1. Copier ce fichier tel quel dans `docs/lessons.md`
2. Ajouter au §3 les leçons **spécifiques** au projet, chacune avec :
   - **Titre** : pattern nommé
   - **Origine** : incident concret (date + commit/PR si applicable)
   - **Why** : raison sous-jacente
   - **How** : pattern canonique à appliquer
3. Ajouter au §4 les anti-patterns process projet-specific (avec cas réel daté)

Ne pas éditer les §1-2 (principes universels).
