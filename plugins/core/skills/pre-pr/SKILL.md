---
name: pre-pr
description: Séquence de vérifications avant de créer une PR — lint + typecheck + build + check:sizes ratchet + résumé bloquant. À invoquer après dernière modif, avant `git push` ou `gh pr create`. Shift-left du job quality de CI.
---

# Skill `/pre-pr`

Invocation manuelle. Lance la séquence des vérifications locales **avant** de créer une PR, pour éviter le ping-pong CI.

## Quand l'invoquer

- Avant `git push` qui déclenche une PR
- Avant `gh pr create` directement
- Sur demande ("/pre-pr", "vérif pre-PR", "ready to push?")

## Méthode

Lancer chaque check **séquentiellement** et stopper au premier fail :

1. **Lint** : `npm run lint` (eslint --quiet)
2. **Typecheck** : `npm run typecheck` (tsc --noEmit)
3. **Build** : `node ace build --ignore-ts-errors` (Vite + tsc)
4. **File-size ratchet** : `node scripts/check-file-sizes.js`

Si un check fail :
- Reporter la sortie (les 20 dernières lignes utiles)
- Proposer un fix : pour lint/typecheck → corriger les erreurs ; pour build → vérifier les imports/exports ; pour ratchet → splitter le fichier dépassant ou regénérer baseline (`scripts/check-file-sizes.js --baseline` après split légitime)
- Stopper la séquence (pas la peine de continuer)
- Verdict : `NOT READY — fix <X> avant retry`

Si tous OK :
- Verdict : `READY TO PR`
- Bonus suggestions :
  - Proposer `/secu` pour scan-secu complet si modifs touchent backend/migrations
  - Proposer `/ux-review <page>` si modifs touchent `.edge`
  - Rappeler de mettre à jour `docs/dev-changelog.md` si feature majeure

## Sources de vérité

- `CLAUDE.md` §1 (commandes courantes)
- `CLAUDE.md` §14 (limites taille + ratchet)
- `scripts/check-file-sizes.js` (mécanique baseline)
- `.github/workflows/ci.yml` job `quality` (que ce skill mirroir)

## Format de sortie

```
### Pre-PR Check — résumé

[✓] Lint        — OK
[✓] Typecheck   — OK
[✗] Build       — FAIL : <extrait erreur>
[ ] Ratchet     — skipped (séquence arrêtée)

**Verdict** : NOT READY

**Fix** :
1. Build error — <description> → <solution>

**Retry** : relance `/pre-pr` une fois fixé.
```

## Règle d'or

Sans complaisance — si un check fail, on stoppe. Pas de "lint warning OK", pas de "ratchet à voir après". Tous les checks doivent passer pour valider la PR. Si une exception est légitime (rare), elle s'enregistre dans la baseline (`--baseline` après split réel) ou via `// eslint-disable-next-line` documenté.
