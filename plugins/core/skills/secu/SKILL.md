---
name: secu
description: Lance scan-secu.sh (étapes tier OWASP pre-push), parse les FAIL/WARN par étape, résume et propose un fix concret pour chaque FAIL. À invoquer avant `git push` ou sur demande. Utilise scan-secu.sh comme source de vérité — pas de duplication des règles ici.
---

# Skill `/secu`

Invocation manuelle. Wrapper du script `scan-secu.sh` (étapes tier OWASP pre-push, nombre auto-compté) avec parsing du résultat et résumé actionnable.

## Quand l'invoquer

- Avant `git push` sur main/develop/feat-lp
- Après une modification touchant du code backend, des templates, des migrations ou des dépendances
- Sur demande explicite ("/secu", "lance le scan sécu", "verif pre-push")

## Méthode

1. **Exécuter** : `bash scan-secu.sh` depuis la racine projet
2. **Parser** la sortie : chaque étape se conclut par `OK` / `WARN` / `FAIL`
3. **Pour chaque FAIL** :
   - Identifier l'étape (numéro affiché) et la règle violée
   - Lire le contexte (souvent le fichier + ligne mentionnés dans la sortie)
   - Proposer le fix canonique en citant la source (`CLAUDE.md` du projet, `docs/anti-patterns.md`, commentaire de l'étape)
   - Suggérer le subagent à invoquer pour audit approfondi si pertinent
4. **Pour chaque WARN** : résumer en 1 ligne, ne pas bloquer
5. **Résumé final** : verdict global (FAIL > 0 → BLOCKED / 0 → READY TO PUSH)

## Sources de vérité

- `scan-secu.sh` (total auto-compté depuis `scan-secu.d/`)
- `docs/anti-patterns.md` du projet (catalogue)
- Docs domain du projet référencées par le commentaire de chaque étape

## Format de sortie

```
### Scan Sécurité — résumé

**Verdict** : READY TO PUSH | BLOCKED

**Étapes FAIL** (X) :
- Étape 04 (Crypto Math.random) — `src/foo.ts:42` → utiliser `crypto.randomUUID()`
  - Subagent suggéré : `security-multitenant` pour audit complet
- Étape 06 (SQL injection) — `src/bar.ts:88` raw SQL avec `${userId}` → paramètre `?`
  - Subagent suggéré : `data-access-reviewer`
- ...

**Étapes WARN** (Y) — non bloquantes :
- Étape 12 (ReDoS scan) — 2 regex sur `request.input.` à reviewer
- Étape 23 (i18n FR/EN symmetry) — 3 clés manquantes en EN

**Étapes OK** (Z) — listing court.

**Action** : <résumé des fixes à appliquer dans l'ordre>
```

## Règle d'or

Sans complaisance — chaque FAIL est listé et fixé. Pas de "FAIL OK car X". Si une étape FAIL est légitimement à skipper (cas rarissime), suggère l'annotation `// canonical-skip:<rule>:<reason>` (convention scan-secu.sh §22).
