# `/feature` — Closure checklist

Référence chargée par `SKILL.md` step 9. Actions de clôture au merge d'une feature.

## 1. Dev changelog (toujours)

Ajouter une entrée datée dans [`docs/dev-changelog.md`](../../../docs/dev-changelog.md) avec :

- **Date** : YYYY-MM-DD (date du merge)
- **Feature** : nom
- **Scope** : 1-2 lignes
- **Migration(s)** : list si applicable
- **Breaking change** : oui/non, si oui détailler
- **Commit principal** : `<hash short>`

Exemple :

```markdown
### 2026-05-31 — Custom report builder (feat-reports)

- Scope : nouveau module Reports avec 3 templates (revenus, contacts, performances)
- Migration : `1900000050000_create_reports_and_templates.ts`
- Breaking : non
- Commit : `b7b8a32e`
```

## 2. Benchmark concurrents (si applicable)

Si la feature révèle qu'un concurrent doit être réaudité (parce qu'il a probablement aussi cette feature ou un équivalent qu'on devrait comparer), ajouter une note dans `docs/competitive-benchmark/<concurrent>.md` :

```markdown
> **À enrichir prochain audit (2026-XX-XX)** : comparer notre feature `<nom>` à leur module `<leur-module>`.
```

## 3. Axes de différenciation (si nouvel angle)

Si la feature consolide ou ouvre un nouvel axe de différenciation par rapport au benchmark, l'ajouter à `docs/competitive-benchmark/README.md` section **"Axes de différenciation actifs"** :

```markdown
- **<nom de l'axe>** : <description courte>. Source : feature `<nom>` (2026-XX-XX).
```

## 4. Memory cross-session (si pattern réutilisable)

Si l'implémentation a révélé un pattern réutilisable (bon ou mauvais), créer une memory :

- Pattern récurrent → memory `feedback_<nom>.md`
- Décision projet importante → memory `project_<nom>.md`
- Référence externe découverte → memory `reference_<nom>.md`

Cf `~/.claude/projects/.../memory/MEMORY.md` pour l'index.

## 5. Skill ou subagent à ajouter (si scope >3 fois)

Si le scope est récurrent (≥ 3 features similaires), envisager :
- Ajouter un skill custom (`/<nom>-check`) — cf `superpowers:writing-skills`
- Ajouter un subagent — cf `docs/claude-config/experts.md` §11 maintenance
