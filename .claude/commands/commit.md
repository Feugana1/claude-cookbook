---
description: Génère un commit Conventional Commits sur les fichiers staged, avec discipline cookbook (pas de --no-verify, pas d'amend, review avant commit si diff non-trivial).
---

# /commit — Commit discipliné (Conventional Commits)

Générer un commit propre sur `git diff --cached`. Respecte la discipline cookbook :

- **Jamais `--no-verify`** (permission deny active dans `settings.json`)
- **Jamais amend** — nouveau commit toujours
- **Format Conventional Commits** : `type(scope): sujet` (≤ 50 chars)
- **Body** uniquement si le "why" n'est pas évident dans le titre
- **Si diff non-trivial** (≥ 2 fichiers OU ≥ 50 lignes OU touche `app/middleware/migrations/routes`) : invoquer `code-reviewer` subagent AVANT le commit

## Types Conventional Commits

| Type | Usage |
|---|---|
| `feat` | Nouvelle feature user-facing |
| `fix` | Correction de bug |
| `refactor` | Restructuration sans changement de comportement |
| `perf` | Optimisation performance |
| `docs` | Doc uniquement |
| `test` | Tests uniquement |
| `chore` | Maintenance, deps, config non-user-facing |
| `style` | Formatting (pas de style JS/CSS user-facing) |
| `ci` | CI/CD config |
| `build` | Build system |

## Méthode

1. **Lire staged** : `git diff --cached --stat` + `git diff --cached --name-only`
2. **Compter** : fichiers, lignes ±. Classifier trivial / standard / substantial.
3. **Si substantial (>10 fichiers ou >300L)** : suggérer split via `/semantic-commit` (si présent) ou proposer 2-3 commits logiques manuels.
4. **Si non-trivial** : invoquer `code-reviewer` subagent d'abord. Attendre verdict SHIP avant commit.
5. **Analyser intention** : lire le diff, extraire le "quoi" (1 phrase) + "pourquoi" (si non évident).
6. **Formuler message** :
   - Titre : `type(scope): sujet impératif ≤ 50 chars` (pas de point final)
   - Body optionnel : 1-3 lignes expliquant le **pourquoi** (pas le quoi — le diff le montre)
   - Footer optionnel : `Co-Authored-By: Claude <noreply@anthropic.com>` si tu génères le message
7. **Commit** via HEREDOC pour préserver formatting :

```bash
git commit -m "$(cat <<'EOF'
type(scope): sujet

Body si nécessaire.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

8. **Vérifier** : `git status` post-commit. Si hook precommit a bloqué (typecheck fail, ratchet fail), fix puis re-stage puis NOUVEAU commit (pas amend).

## Anti-patterns refusés

- ❌ `git commit --no-verify` (blocked par settings)
- ❌ `git commit --amend` (préférer nouveau commit)
- ❌ Titre "update stuff", "wip", "fixes" — vague
- ❌ Body qui répète le diff ("Modified file X to add function Y") — décrire le **pourquoi**
- ❌ Bundler feat+fix+refactor dans un seul commit — splitter
- ❌ Commit sans avoir invoqué `code-reviewer` sur diff non-trivial

## Format de sortie

```
### Commit — proposé

**Scope détecté** : trivial | standard | substantial
**Fichiers** : X | **Lignes** : +N/-M
**Type** : feat | fix | refactor | ...
**Intention** : <1 phrase>

**Review** :
- [Trivial] Skip code-reviewer
- [Standard/Substantial] `code-reviewer` invoqué → verdict SHIP | NEEDS CHANGES | REJECT

**Message proposé** :
```
type(scope): sujet impératif

Body si pertinent.

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Action** :
- Confirmer avant commit
- Si NEEDS CHANGES : appliquer fixes, re-stage, re-invoquer /commit
```

## Sources

- Conventional Commits spec : https://www.conventionalcommits.org
- Cookbook code-reviewer : `.claude/agents/stacks/adonisjs/code-reviewer.md` (couche 5 — invoqué avant commit non-trivial)
- Cookbook precommit hook : `.claude/hooks/precommit-check.sh` (typecheck + ratchet automatiques)
