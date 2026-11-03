---
name: pre-pr
description: Séquence de vérifications avant de créer une PR — lint, typecheck, tests, build, checks du projet (toolchain détectée) + résumé bloquant. À invoquer après dernière modif, avant `git push` ou `gh pr create`. Shift-left du job quality de CI.
---

# Skill `/pre-pr`

Invocation manuelle. Lance la séquence des vérifications locales **avant** de créer une PR, pour éviter le ping-pong CI.

## Quand l'invoquer

- Avant `git push` qui déclenche une PR
- Avant `gh pr create` directement
- Sur demande ("/pre-pr", "vérif pre-PR", "ready to push?")

## Méthode

**Détecter la toolchain** (ne rien supposer) : lire les `scripts` de `package.json` (ou `Makefile`, `pyproject.toml`, `Cargo.toml`, `go.mod`) et le `CLAUDE.md` du projet (section commandes). Construire la séquence à partir de ce qui existe :

1. **Lint** — script `lint`
2. **Typecheck** — script `typecheck` / `tsc --noEmit`, `mypy`, `cargo check`…
3. **Tests** — script `test` (rapide / unitaires seulement si la suite complète est longue)
4. **Build** — script `build`
5. **Checks du projet** — tout script de garde additionnel (ex : ratchet de taille de fichiers, `check:*`) documenté dans `CLAUDE.md` ou la CI

Lancer **séquentiellement**, stopper au premier fail. Ne pas inventer un check absent du projet : le signaler « non configuré » et continuer.

Si un check fail :
- Reporter la sortie (les 20 dernières lignes utiles)
- Proposer un fix ciblé (corriger les erreurs ; vérifier imports/exports pour un build ; splitter un fichier pour un ratchet de taille)
- Stopper la séquence
- Verdict : `NOT READY — fix <X> avant retry`

Si tous OK :
- Verdict : `READY TO PR`
- Suggestions : `/secu` si modifs backend/migrations/dépendances ; rappeler de mettre à jour le changelog du projet si feature majeure ; pour un pack de stack avec audit UX (ex : `/ux-review`), le proposer si des templates UI changent

## Sources de vérité

- `CLAUDE.md` du projet (commandes courantes, limites)
- La CI du projet (job qualité) : ce skill la mirroir en local

## Format de sortie

```
### Pre-PR Check — résumé

[✓] Lint        — OK
[✓] Typecheck   — OK
[✗] Build       — FAIL : <extrait erreur>
[ ] Tests       — skipped (séquence arrêtée)

**Verdict** : NOT READY

**Fix** :
1. Build error — <description> → <solution>

**Retry** : relance `/pre-pr` une fois fixé.
```

## Règle d'or

Sans complaisance — si un check fail, on stoppe. Pas de "lint warning OK", pas de "ratchet à voir après". Tous les checks doivent passer pour valider la PR. Une exception légitime (rare) s'enregistre de façon explicite et documentée dans le projet (baseline, `eslint-disable-next-line` justifié).
