# AGENTS.md — opérer ce cookbook

Instructions pour un agent Claude Code. Vue d'ensemble : [README.md](README.md). Install et vérification : [docs/claude-config/setup.md](docs/claude-config/setup.md). Catalogue d'agents : [docs/claude-config/experts.md](docs/claude-config/experts.md). Comptes à jour : `bash scripts/inventory.sh`.

`$COOKBOOK_DIR` = chemin du clone du cookbook (à demander si inconnu).

## « Installe / bootstrap ce cookbook »

1. Cible = cwd ou chemin explicite.
2. Stack : demander à l'user — projet AdonisJS/Node/TS → `--stack=adonisjs`, sinon `--stack=none`.
3. `bash $COOKBOOK_DIR/bootstrap-claude.sh <path> --stack=<mode>` (ou plugin : voir setup.md §1).
4. Confirmer : agents/skills/commands/hooks installés (lire la sortie du script, ne pas recopier de chiffres), `CLAUDE.md` minimal à enrichir, `inheritance-map.md` pour le mapping override.
5. Avant le 1er commit d'une nouvelle feature : `product-strategist` **si** `PRODUCT.md` ou `docs/vision.md` existe. Sinon ne pas l'invoquer (`BLOCKED-SETUP`) et proposer de créer une vision minimale (`docs/templates/PRODUCT.md`).

## « Audite avec scan-secu »

1. Présence : `ls scripts/scan-secu.sh scripts/scan-secu.d/`. Si absent : copier les **deux** depuis `$COOKBOOK_DIR/scripts/`.
2. `bash scripts/scan-secu.sh` (le total d'étapes est auto-compté).
3. Résumer par tier (T1 BLOCKER / T2 IMPORTANT / T3 ADVISORY) et « Top risks open ». Proposer un fix pour chaque T1 FAIL d'abord.

## « Ajoute un agent »

Suivre [experts.md §5](docs/claude-config/experts.md) : vérifier l'absence de doublon, générique → `roles/`, stack → `stacks/<stack>/`, frontmatter `name/description/tools/model` avec description **active**. Projet-spécifique : reste local. Générique : proposer la copie vers le cookbook.

## « Applique une lesson learned »

Lire `docs/lessons.md`, appliquer, ajouter le pattern à `docs/anti-patterns.md` s'il est nouveau, proposer la remontée au cookbook s'il est générique.

## Règles du cookbook

- **Un rôle = un fichier. Générique OU stack, jamais les deux** pour un même use case. Un fichier `stacks/X` durcit son `roles/Y`.
- **Un expert dit REJECT → tu corriges, tu ne contournes pas.**
- Nouvelle feature → `/feature` (ou `product-strategist` si vision documentée). Avant commit non-trivial → `code-reviewer`/`reviewer`. Avant push → `scan-secu.sh`.
- Pas de cérémonie (CHANGELOG, releases, multi-lang) : kit perso solo.
- **Aucun chiffre en dur** (nombre d'agents, de steps, version) dans les docs : utiliser `scripts/inventory.sh`. La version vit uniquement dans `.claude-plugin/plugin.json`.

## Si tu modifies le cookbook

- Agents/hooks/skills **100 % génériques** : rien de spécifique à un projet. Le contenu stack va dans `stacks/<stack>/`.
- Respecter les limites §14 (controllers ≤ 300 L, services ≤ 400 L, templates ≤ 800 L), exemples inclus.
- Valider : `bash scripts/scan-secu.sh` reste cohérent ; `bash scripts/inventory.sh` tourne ; `bash -n` sur les scripts modifiés.
- Remontée depuis un projet : implémenter localement, valider en prod, puis proposer « générique, je copie vers le cookbook ? » avant tout `cp` vers `$COOKBOOK_DIR`.
- Les memories Claude Code restent par-projet ; un pattern universel peut être copié dans `docs/lessons.md` avec l'accord de l'user.
