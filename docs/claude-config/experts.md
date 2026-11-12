# Claude Code — catalogue d'experts

> Démarche : transformer les règles dures d'un projet en mécanismes déterministes (hooks, permissions, subagents).
> Source de vérité de chaque agent = son frontmatter (`description`, `tools`, `model`). Ce doc ne le recopie pas.
> Liste et comptes à jour : `bash scripts/inventory.sh`.

---

## 1. Pourquoi ce système

Une instruction `CLAUDE.md` est **consultative** (suivie ~80 % du temps). Suffisant pour une convention de nommage, insuffisant pour une règle de sécurité ou une règle métier critique. Une règle **dure** doit être déterministe :

| Type de règle | Mécanisme |
|---|---|
| Pattern grepable interdit | **Hook** `PostToolUse` (grep + exit 2) |
| Action destructive (`--no-verify`, force push, `rm -rf`) | **Permission** `deny` |
| Vérification contextuelle (isolation tenant, charte design) | **Subagent expert** sur sa propre source de vérité |
| Workflow volontaire (audit UX, pré-PR, scan sécu) | **Skill** invoqué par l'humain |

Le but n'est pas de remplacer `CLAUDE.md` mais de matérialiser ses sections P0 sans dépendre de la discipline d'une session.

## 2. Trois niveaux

| Niveau | Mécanisme | Déclenchement |
|---|---|---|
| **N1 Hook** | script `PostToolUse` : match path + grep | automatique à chaque Edit/Write |
| **N2 Subagent** | `.claude/agents/*.md` | Claude délègue d'après la `description` |
| **N3 Skill** | `.claude/skills/*/SKILL.md` | l'humain tape `/<skill>` |

Un hook **ne lance pas** de subagent : il bloque les P0 et **suggère** en sortie les experts à invoquer.

## 3. Règle d'or — « l'expert prend le dessus, sans complaisance »

Contrat de tout expert :

1. **Prime sur son scope** : sa décision l'emporte sur les heuristiques générales de la session.
2. **Charge sa source de vérité** avant tout finding. Jamais « de mémoire ».
3. **Sans complaisance** : aucun finding minimisé. Si 5 règles sont violées, il en rapporte 5.
4. **Reste dans son scope** (un expert tenant ne commente pas le CSS).
5. **Cite `file:line`** + la règle source. Un finding non sourcé est ignoré.
6. **Sortie standard** : P0 / P1 / Quick wins / Déjà correct. Pas de prose libre.

Un expert qui bloque arrête le merge : on corrige, on ne contourne pas.

## 4. Catalogue par couche

Install **exclusif** : un rôle générique et son override stack ne coexistent jamais (`bootstrap-claude.sh --stack=none|<pack>`). Détail du mapping : README de chaque pack (`plugins/<pack>/README.md`).

| Couche | Rôle | Agent core (`plugins/core/agents/`) | Pack AdonisJS (`plugins/adonisjs/agents/`) | Pack Expo (`plugins/expo/agents/`) |
|---|---|---|---|---|
| 0 Strategic gate | valide la feature avant code | `product-strategist` | — | — |
| 1 Architect | structure, conventions, API | `architect` | `back-architect` | `mobile-architect` |
| 2 Cross-cutting | sécurité, données | `security`, `performance` | `security-multitenant`, `data-access-reviewer`, `migration-reviewer` | `mobile-security`, `mobile-performance` |
| 3 Domain | règles métier | — | aucun : modèle dans `docs/templates/example-domain-agent.md` | idem |
| 4 UI / linter | UX web et mobile ; grep rapide (haiku) | `frontend` | `edge-anti-patterns` | — (`frontend` conservé) |
| 5 Final gate | review avant commit | `reviewer` | `code-reviewer` | `mobile-code-reviewer` |
| Transverse | investigation, tests | `analyzer`, `qa` | — | — |

Notes d'usage :
- `product-strategist` est la gate d'entrée des **nouvelles features** (pas bugfix ni refactor). Sans vision produit (`PRODUCT.md` ou `docs/vision.md`), il rend `BLOCKED-SETUP`.
- `code-reviewer` / `mobile-code-reviewer` / `reviewer` **orchestrent** : ils lancent `scan-secu.sh` et lisent sa sortie, ils ne re-greppent pas.
- Les experts domain (compta, marketplace, quotas…) sont **projet-spécifiques** : ils vivent dans le `.claude/agents/` du projet, jamais dans le cookbook.

## 5. Maintenance

### Ajouter un subagent

1. Vérifier qu'aucun agent existant ne couvre le besoin.
2. Créer `plugins/core/agents/<name>.md` (générique) ou `plugins/<stack>/agents/<name>.md` (stack). Le bootstrap les installe sous `.claude/agents/roles/` et `.claude/agents/stacks/<stack>/`. Frontmatter `name / description / tools / model`.
3. `description` **active** : « Use PROACTIVELY when… », « Triggers when user says… » (pas « Specialized in… »).
4. Charger une source de vérité dédiée, sortie P0 / P1 / Quick wins / Déjà correct.
5. Si générique : l'ajouter ici (ligne du tableau §4). Si projet-spécifique : reste local.

### Ajouter un skill

1. Un skill est une invocation **humaine** ; un subagent est une délégation **auto**. Ne pas recouvrir un agent existant.
2. `plugins/core/skills/<name>/SKILL.md` (ou `plugins/<stack>/skills/`) avec frontmatter `name / description`. Installé en `.claude/skills/<name>/`.
3. Documenter la source de vérité qu'il charge.

### Ajouter un pattern P0 au hook

1. Vérifier qu'il est **grepable** (sinon → subagent).
2. Ajouter le `case` dans le bon path-branch du hook dispatcher de la stack.
3. Message clair : `[hook:<class>-P0] BLOCKED — <pattern> dans <file> — solution`.
4. Tester avec un Edit volontaire (exit 2 attendu).

## 6. Cadence de review

- **Trimestriel** : quels skills/agents ont été invoqués, ajuster les `description` si sur/sous-invocation.
- **Après chaque incident** : un hook P0 ou un expert l'aurait-il bloqué ? Sinon ajouter la règle.
- **Après chaque évolution majeure de Claude Code** : re-vérifier hooks (format JSON I/O, matchers), frontmatter agents/skills, format plugin.
