#!/usr/bin/env bash
# Détecte des noms propres à un projet dans les fichiers versionnés du cookbook.
# Le cookbook doit rester générique. Les motifs ne sont PAS dans le dépôt :
#   - variable d'environnement LEAK_PATTERN (regex ERE), ou
#   - fichier local `.leak-patterns` (gitignoré) : un motif par ligne, '#' = commentaire.
# CI : définir la variable de dépôt GitHub LEAK_PATTERN.
# Sans motif configuré, le script le dit et sort 0.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

pattern="${LEAK_PATTERN:-}"
if [ -z "$pattern" ] && [ -f .leak-patterns ]; then
  pattern=$(grep -vE '^[[:space:]]*(#|$)' .leak-patterns | paste -sd '|' -)
fi
if [ -z "$pattern" ]; then
  echo "[leak-check] aucun motif configuré (LEAK_PATTERN ou .leak-patterns) : rien à vérifier."
  exit 0
fi

# docs/templates/CLAUDE.md est destiné à être personnalisé par chaque projet.
leaks=$(git grep -nIE "$pattern" -- . ':!docs/templates/CLAUDE.md' ':!.leak-patterns' 2>/dev/null || true)
if [ -n "$leaks" ]; then
  echo "[leak-check] ERREUR : noms propres à un projet dans des fichiers génériques :"
  printf '%s\n' "$leaks" | cut -c1-160
  exit 1
fi
echo "[leak-check] OK : aucun nom de projet dans les fichiers versionnés."
