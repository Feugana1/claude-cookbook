# Pack AdonisJS — `cookbook-adonisjs`

Pack optionnel de stack pour AdonisJS 6 / Lucid / Edge / Vine. Dépend de `cookbook-core`. Comptes à jour : `bash scripts/inventory.sh`.

Contenu : `agents/` (experts stack-aware), `skills/` (`/ux-review`), `hooks/` (dispatcher de patterns P0), `scripts/scan-secu.d/` (steps Edge/Lucid/Adonis) + `scripts/check-file-sizes.js`, `docs/dispatch-matrix.md`.

## Principe — mapping rôles ↔ stack

**On installe soit le rôle générique, soit son override stack, jamais les deux pour un même use case.** Deux experts sur le même scope se marchent dessus, rendent l'invocation ambiguë et gaspillent des tokens.

Un agent du pack **durcit** un rôle du core : il garde la règle d'or (sources chargées avant analyse, stay in scope, format P0 / P1 / Quick wins / Déjà correct, cite `file:line`) et ajoute les conventions de la stack. Claude Code ne supporte pas l'héritage littéral entre fichiers agents : chaque agent du pack est autoportant.

**Application de l'exclusivité** : uniquement par `bootstrap-claude.sh --stack=adonisjs` (il n'installe pas les rôles remplacés). En installation plugin (`cookbook-core` + `cookbook-adonisjs`), les deux jeux coexistent, car une dépendance de plugin ne peut pas retirer un agent du core.

## Rôles du core remplacés par un agent du pack

| Rôle core | Remplacé par | Ce que le pack ajoute |
|---|---|---|
| `architect` | `back-architect` | limites de taille de fichiers, Vine, ordre des routes, helpers `_helpers/` |
| `reviewer` | `code-reviewer` | review PR-style stack-aware, orchestre les autres experts du pack |
| `security` | `security-multitenant` | isolation tenant, IDOR via `.where('userId', …).firstOrFail()`, CSRF, URLs signées |

## Rôles du core conservés (aucun override)

`analyzer`, `frontend`, `performance`, `product-strategist`, `qa`. Le linter `edge-anti-patterns` est en **paire** avec `frontend` (le rôle fait WCAG/UX, le linter fait les patterns Edge grepables).

## Experts propres à la stack (aucun rôle équivalent)

| Expert | Scope |
|---|---|
| `data-access-reviewer` | ORM Lucid (preload vs load), raw SQL, pool, storage, TTL cache (grep rapide, haiku) |
| `edge-anti-patterns` | templates `.edge` + Alpine, patterns P0/P1 grepables (haiku) |
| `migration-reviewer` | `database/migrations/*.ts` : idempotence, DEFAULT sur NOT NULL, JSONB, extension d'enum |

Un expert **domain** (workflow/email, compta, marketplace…) est spécifique à un produit : il vit dans le `.claude/agents/` du projet. Modèle à copier : `docs/templates/example-domain-agent.md`.

## Diagramme

```
                       core (agents/)                 pack adonisjs (agents/)
Couche 0 strategic     product-strategist   ─────►    (conservé)
Couche 1 architect     architect            ─────►    back-architect       (durcit)
Couche 2 cross-cutting security             ─────►    security-multitenant (durcit)
                       (aucun)              ─ADD──►   data-access-reviewer
                       (aucun)              ─ADD──►   migration-reviewer
Couche 4 linter        frontend             ─PAIR─    edge-anti-patterns   (linter étroit)
Couche 5 final gate    reviewer             ─────►    code-reviewer        (durcit, orchestre)
Conservés tels quels : analyzer, performance, qa
```

## Ajouter une stack

1. Créer `plugins/<stack>/` avec `.claude-plugin/plugin.json` (`"dependencies": ["cookbook-core"]`, pas de `version` : elle vit dans le core), et les sous-dossiers utiles : `agents/`, `skills/`, `hooks/`, `scripts/scan-secu.d/`, `docs/`.
2. Ajouter l'entrée dans `.claude-plugin/marketplace.json` (`"source": "./plugins/<stack>"`).
3. Créer `plugins/<stack>/pack.conf` (`DESCRIPTION=…`, `REPLACES="rôles du core remplacés"`) : le bootstrap découvre la stack tout seul, sans éditer le script. Un `settings.hooks.json` optionnel est fusionné dans `.claude/settings.json`.
4. Chaque agent du pack dit en tête quel agent core il durcit et ce que la stack ajoute (règle d'or conservée, conventions stack en plus).
5. Valider : `claude plugin validate .` et `bash scripts/inventory.sh`.

Le core ne doit jamais nommer un agent d'un pack.
