#!/usr/bin/env bash
# ============================================================================
# bootstrap-claude.sh — Copie le cookbook Claude vers un projet cible
#
# Usage:
#   bash bootstrap-claude.sh <path-to-project>          # init projet vierge
#   bash bootstrap-claude.sh <path-to-project> --update # update fichiers cookbook seuls
#
# Le script copie .claude/, scripts/, docs/ vers le projet cible.
# Mode --update : preserve les fichiers spécifiques projet (CLAUDE.md root,
# agents custom non-cookbook, etc.).
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Localise la racine du cookbook (= dossier du script)
COOKBOOK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -lt 1 ]; then
  echo -e "${RED}Usage: bash bootstrap-claude.sh <path-to-project> [--update]${NC}"
  echo ""
  echo "Examples:"
  echo "  bash bootstrap-claude.sh ~/code/my-new-saas"
  echo "  bash bootstrap-claude.sh . --update"
  exit 1
fi

TARGET="$(cd "$1" && pwd)"
UPDATE_MODE=false
if [ "${2:-}" = "--update" ]; then
  UPDATE_MODE=true
fi

if [ ! -d "$TARGET" ]; then
  echo -e "${RED}Target directory does not exist: $TARGET${NC}"
  exit 1
fi

echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Claude Cookbook → Bootstrap${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "  Source : ${BLUE}${COOKBOOK_ROOT}${NC}"
echo -e "  Target : ${BLUE}${TARGET}${NC}"
echo -e "  Mode   : ${YELLOW}$([ "$UPDATE_MODE" = true ] && echo "UPDATE (preserve project-specific files)" || echo "INIT (fresh setup)")${NC}"
echo ""

# ── Préparer arborescence cible ─────────────────────────────────────────────
mkdir -p "$TARGET/.claude/agents"
mkdir -p "$TARGET/.claude/skills"
mkdir -p "$TARGET/.claude/hooks"
mkdir -p "$TARGET/scripts"
mkdir -p "$TARGET/docs/claude-config"

# ── Copier les agents (8 génériques) ────────────────────────────────────────
echo -e "${GREEN}[1/5]${NC} Agents (8 génériques)..."
for f in "$COOKBOOK_ROOT"/.claude/agents/*.md; do
  cp "$f" "$TARGET/.claude/agents/"
  echo "    + $(basename "$f")"
done

# ── Copier les skills (4 slash commands) ────────────────────────────────────
# NB strip trailing slash sinon macOS BSD cp copie le CONTENU au lieu du dossier
echo -e "${GREEN}[2/5]${NC} Skills (4 slash commands)..."
for dir in "$COOKBOOK_ROOT"/.claude/skills/*/; do
  skillname=$(basename "$dir")
  cp -r "${dir%/}" "$TARGET/.claude/skills/"
  echo "    + /$skillname"
done

# ── Copier les hooks ────────────────────────────────────────────────────────
echo -e "${GREEN}[3/5]${NC} Hooks (auto-routing + precommit)..."
cp "$COOKBOOK_ROOT/.claude/hooks/dispatch-expert.sh" "$TARGET/.claude/hooks/"
cp "$COOKBOOK_ROOT/.claude/hooks/precommit-check.sh" "$TARGET/.claude/hooks/"
chmod +x "$TARGET/.claude/hooks/"*.sh
echo "    + dispatch-expert.sh (chmod +x)"
echo "    + precommit-check.sh (chmod +x)"

# ── Copier les scripts qualité ──────────────────────────────────────────────
echo -e "${GREEN}[4/5]${NC} Scripts qualité..."
cp "$COOKBOOK_ROOT/scripts/scan-secu.sh" "$TARGET/scan-secu.sh"
chmod +x "$TARGET/scan-secu.sh"
cp "$COOKBOOK_ROOT/scripts/check-file-sizes.js" "$TARGET/scripts/"
cp "$COOKBOOK_ROOT/scripts/generate-sbom.sh" "$TARGET/scripts/"
chmod +x "$TARGET/scripts/generate-sbom.sh"
echo "    + scan-secu.sh (root, chmod +x) — 31 steps OWASP 3 tiers"
echo "    + scripts/check-file-sizes.js — ratchet CI"
echo "    + scripts/generate-sbom.sh (chmod +x) — CycloneDX SBOM"

# ── Copier la doc ───────────────────────────────────────────────────────────
echo -e "${GREEN}[5/5]${NC} Docs Claude..."
cp "$COOKBOOK_ROOT/docs/lessons.md" "$TARGET/docs/"
cp "$COOKBOOK_ROOT/docs/anti-patterns.md" "$TARGET/docs/"
cp "$COOKBOOK_ROOT/docs/feature-plan-template.md" "$TARGET/docs/"
cp "$COOKBOOK_ROOT/docs/ux-audit-prompt.md" "$TARGET/docs/"
cp "$COOKBOOK_ROOT/docs/claude-config/README.md" "$TARGET/docs/claude-config/"
cp "$COOKBOOK_ROOT/docs/claude-config/experts.md" "$TARGET/docs/claude-config/"
cp "$COOKBOOK_ROOT/docs/claude-config/setup.md" "$TARGET/docs/claude-config/"
cp "$COOKBOOK_ROOT/docs/claude-config/skills.md" "$TARGET/docs/claude-config/"
cp "$COOKBOOK_ROOT/docs/claude-config/superpowers-integration.md" "$TARGET/docs/claude-config/"
echo "    + docs/lessons.md (Karpathy 4 + leçons)"
echo "    + docs/anti-patterns.md (catalogue)"
echo "    + docs/feature-plan-template.md (~200L max)"
echo "    + docs/ux-audit-prompt.md (6 axes UX)"
echo "    + docs/claude-config/{README,experts,setup,skills,superpowers-integration}.md"

# ── CLAUDE.md root : init seulement si absent et mode INIT ──────────────────
# Copie le template canonical (docs/templates/CLAUDE.md) qui inclut §5
# Domain Model Glossary — le seam que tous les sub-agents et scan-secu
# référencent pour les rules tenant-scoped / soft-delete.
if [ "$UPDATE_MODE" = false ] && [ ! -f "$TARGET/CLAUDE.md" ]; then
  echo ""
  echo -e "${YELLOW}Generating CLAUDE.md from template (edit §5 Domain Model Glossary for your project)...${NC}"
  cp "$COOKBOOK_ROOT/docs/templates/CLAUDE.md" "$TARGET/CLAUDE.md"
  echo "    + CLAUDE.md (template — edit §5 PRIMARY_MODELS first)"
elif [ "$UPDATE_MODE" = true ] && [ -f "$TARGET/CLAUDE.md" ]; then
  echo ""
  echo -e "${YELLOW}CLAUDE.md preserved (project-specific, not overwritten).${NC}"
fi

# ── Récap final ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}${BOLD}✓ Bootstrap terminé${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}Installé dans ${TARGET}${NC} :"
echo -e "  • 8 sub-agents génériques (.claude/agents/)"
echo -e "  • 4 skills (.claude/skills/feature, pre-pr, secu, ux-review)"
echo -e "  • 2 hooks (.claude/hooks/dispatch-expert + precommit-check)"
echo -e "  • 3 scripts (scan-secu.sh orchestrator + scan-secu.d/ 33 step modules + check-file-sizes.js + generate-sbom.sh)"
echo -e "  • 9 docs (lessons, anti-patterns, feature-plan-template, ux-audit-prompt + claude-config/)"
if [ "$UPDATE_MODE" = false ]; then
  echo -e "  • CLAUDE.md (template — §5 Domain Model Glossary à remplir)"
fi
echo ""
echo -e "${BOLD}Next steps${NC} :"
echo -e "  1. ${BLUE}Éditer${NC} CLAUDE.md §5 Domain Model Glossary — lister PRIMARY_MODELS du projet"
echo -e "  2. ${BLUE}Éditer${NC} CLAUDE.md §1 Stack + §2 Conventions + §3 i18n"
echo -e "  3. ${BLUE}Export${NC} PRIMARY_MODELS_RE dans scripts/scan-secu.env (cf §5)"
echo -e "  4. ${BLUE}Ajouter${NC} agents domain-specific dans .claude/agents/ (les 8 du cookbook sont génériques)"
echo -e "  5. ${BLUE}Première feature${NC} : invoquer subagent product-strategist via Agent tool"
echo -e "  6. ${BLUE}Avant commit${NC} : code-reviewer"
echo -e "  7. ${BLUE}Avant push${NC} : bash scan-secu.sh"
echo ""
echo -e "${YELLOW}Doc canonical${NC} : docs/claude-config/experts.md (catalogue 6 couches)"
echo -e "${YELLOW}Discipline${NC}   : docs/lessons.md §1 (Karpathy 4)"
echo ""
