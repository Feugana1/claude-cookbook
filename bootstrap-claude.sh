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
mkdir -p "$TARGET/.claude/agents/roles"
mkdir -p "$TARGET/.claude/agents/stacks/adonisjs"
mkdir -p "$TARGET/.claude/skills"
mkdir -p "$TARGET/.claude/hooks"
mkdir -p "$TARGET/scripts"
mkdir -p "$TARGET/docs/claude-config"
mkdir -p "$TARGET/.claude-plugin"

# ── Copier les agents (17 total : 10 roles génériques opus + 7 stack AdonisJS) ──────
echo -e "${GREEN}[1/6]${NC} Agents (17 total : 10 roles/ opus + 7 stacks/adonisjs/)..."
for f in "$COOKBOOK_ROOT"/.claude/agents/roles/*.md; do
  cp "$f" "$TARGET/.claude/agents/roles/"
  echo "    + roles/$(basename "$f")"
done
for f in "$COOKBOOK_ROOT"/.claude/agents/stacks/adonisjs/*.md; do
  cp "$f" "$TARGET/.claude/agents/stacks/adonisjs/"
  echo "    + stacks/adonisjs/$(basename "$f")"
done

# ── Copier les skills (5) + commands (13) ──────────────────────────────────
# NB strip trailing slash sinon macOS BSD cp copie le CONTENU au lieu du dossier
echo -e "${GREEN}[2/6]${NC} Skills (5) + commands (13)..."
for dir in "$COOKBOOK_ROOT"/.claude/skills/*/; do
  skillname=$(basename "$dir")
  cp -r "${dir%/}" "$TARGET/.claude/skills/"
  echo "    + skill /$skillname"
done
mkdir -p "$TARGET/.claude/commands"
for f in "$COOKBOOK_ROOT"/.claude/commands/*.md; do
  cp "$f" "$TARGET/.claude/commands/"
  echo "    + command /$(basename "$f" .md)"
done

# ── Copier les hooks (3) ────────────────────────────────────────────────────
echo -e "${GREEN}[3/6]${NC} Hooks (3 : dispatch-expert + precommit-check + preserve-file-permissions)..."
cp "$COOKBOOK_ROOT/.claude/hooks/dispatch-expert.sh" "$TARGET/.claude/hooks/"
cp "$COOKBOOK_ROOT/.claude/hooks/precommit-check.sh" "$TARGET/.claude/hooks/"
cp "$COOKBOOK_ROOT/.claude/hooks/preserve-file-permissions.sh" "$TARGET/.claude/hooks/"
chmod +x "$TARGET/.claude/hooks/"*.sh
echo "    + dispatch-expert.sh (chmod +x)"
echo "    + precommit-check.sh (chmod +x)"
echo "    + preserve-file-permissions.sh (chmod +x)"

# ── Copier les scripts qualité ──────────────────────────────────────────────
echo -e "${GREEN}[4/6]${NC} Scripts qualité..."
cp "$COOKBOOK_ROOT/scripts/scan-secu.sh" "$TARGET/scan-secu.sh"
chmod +x "$TARGET/scan-secu.sh"
mkdir -p "$TARGET/scripts/scan-secu.d"
cp "$COOKBOOK_ROOT/scripts/scan-secu.d/"*.sh "$TARGET/scripts/scan-secu.d/"
cp "$COOKBOOK_ROOT/scripts/check-file-sizes.js" "$TARGET/scripts/"
cp "$COOKBOOK_ROOT/scripts/generate-sbom.sh" "$TARGET/scripts/"
cp "$COOKBOOK_ROOT/scripts/statusline.sh" "$TARGET/scripts/"
chmod +x "$TARGET/scripts/generate-sbom.sh" "$TARGET/scripts/statusline.sh"
echo "    + scan-secu.sh (root, chmod +x) — 41 steps tier OWASP T1/T2/T3"
echo "    + scripts/scan-secu.d/ — 41 step modules"
echo "    + scripts/check-file-sizes.js — ratchet §14 CI"
echo "    + scripts/generate-sbom.sh (chmod +x) — CycloneDX SBOM"
echo "    + scripts/statusline.sh (chmod +x) — model + \$/jour + %tokens"

# ── Copier la doc ───────────────────────────────────────────────────────────
echo -e "${GREEN}[5/6]${NC} Docs Claude..."
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

# ── Manifest plugin + settings.json + .mcp.json + config ────────────────────
echo -e "${GREEN}[6/6]${NC} Plugin manifest + settings.json + MCP + Conventional Commits config..."
cp "$COOKBOOK_ROOT/.claude-plugin/plugin.json" "$TARGET/.claude-plugin/"
cp "$COOKBOOK_ROOT/.claude-plugin/marketplace.json" "$TARGET/.claude-plugin/"
echo "    + .claude-plugin/plugin.json + marketplace.json (v0.2.0)"

# settings.json : ne pas écraser si présent
if [ ! -f "$TARGET/settings.json" ]; then
  cp "$COOKBOOK_ROOT/settings.json" "$TARGET/settings.json"
  echo "    + settings.json (permissions deny + hooks wire + env + statusLine)"
  echo -e "    ${YELLOW}NOTE${NC}: hooks wire via \${CLAUDE_PLUGIN_ROOT} — restart Claude Code pour les activer."
else
  echo -e "    ${YELLOW}settings.json déjà présent — préservé (fusionner manuellement si nécessaire).${NC}"
fi

# .mcp.json : idem, ne pas écraser
if [ ! -f "$TARGET/.mcp.json" ]; then
  cp "$COOKBOOK_ROOT/.mcp.json" "$TARGET/.mcp.json"
  echo "    + .mcp.json (Context7 + sequential-thinking + fetch + github)"
else
  echo -e "    ${YELLOW}.mcp.json déjà présent — préservé (fusionner manuellement si nécessaire).${NC}"
fi

# Conventional Commits config (commitlint + lefthook + markdownlint + package.json)
for f in commitlint.config.js lefthook.yml .markdownlint.json; do
  if [ ! -f "$TARGET/$f" ]; then
    cp "$COOKBOOK_ROOT/$f" "$TARGET/$f"
    echo "    + $f"
  else
    echo -e "    ${YELLOW}$f déjà présent — préservé.${NC}"
  fi
done
# package.json : jamais copier (chaque projet a le sien). Suggérer merge manuel deps.
if [ ! -f "$TARGET/package.json" ]; then
  echo -e "    ${YELLOW}NOTE${NC}: pas de package.json cible. Créer + ajouter deps :"
  echo -e "        ${BLUE}npm i -D @commitlint/cli @commitlint/config-conventional lefthook markdownlint-cli${NC}"
else
  echo -e "    ${YELLOW}package.json existe déjà — ajouter deps manuellement si commitlint/lefthook pas installés :${NC}"
  echo -e "        ${BLUE}npm i -D @commitlint/cli @commitlint/config-conventional lefthook markdownlint-cli${NC}"
fi

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
echo -e "  • .claude-plugin/{plugin,marketplace}.json (v0.2.0 — plugin natif Claude Code)"
echo -e "  • settings.json (permissions deny + hooks wire + env + statusLine — copié si absent)"
echo -e "  • .mcp.json (Context7 + sequential-thinking + fetch + github — copié si absent)"
echo -e "  • commitlint.config.js + lefthook.yml + .markdownlint.json (Conventional Commits + linting)"
echo -e "  • 17 sub-agents — 10 roles/ (générique opus) + 7 stacks/adonisjs/ (stack-aware sonnet/haiku)"
echo -e "  • 5 skills (.claude/skills/feature, pre-pr, secu, ux-review, multi-agent)"
echo -e "  • 13 commands (.claude/commands/ : commit, semantic-commit, pr-*, plan, refactor, fix-error, explain-code, analyze-*, check-fact, tech-debt)"
echo -e "  • 3 hooks (.claude/hooks/dispatch-expert + precommit-check + preserve-file-permissions)"
echo -e "  • 5 scripts (scan-secu.sh orchestrator ~220L --diff mode + scan-secu.d/ 41 step modules + check-file-sizes.js + generate-sbom.sh + statusline.sh)"
echo -e "  • 9 docs (lessons, anti-patterns, feature-plan-template, ux-audit-prompt + claude-config/)"
echo -e "  • 3 templates (docs/templates/{gitleaks.toml, husky-pre-commit, scan-secu-weekly.yml} — wire manuel après bootstrap)"
if [ "$UPDATE_MODE" = false ]; then
  echo -e "  • CLAUDE.md (template — §5 Domain Model Glossary à remplir)"
fi
echo ""
echo -e "${BOLD}Next steps${NC} :"
echo -e "  1. ${BLUE}Éditer${NC} CLAUDE.md §5 Domain Model Glossary — lister PRIMARY_MODELS du projet"
echo -e "  2. ${BLUE}Éditer${NC} CLAUDE.md §1 Stack + §2 Conventions + §3 i18n"
echo -e "  3. ${BLUE}Export${NC} PRIMARY_MODELS_RE dans scripts/scan-secu.env (cf §5)"
echo -e "  4. ${BLUE}Ajouter${NC} agents domain-specific dans .claude/agents/stacks/<votre-stack>/ (les 7 fournis ciblent AdonisJS)"
echo -e "  5. ${BLUE}Première feature${NC} : invoquer subagent product-strategist via Agent tool"
echo -e "  6. ${BLUE}Avant commit${NC} : code-reviewer"
echo -e "  7. ${BLUE}Avant push${NC} : bash scan-secu.sh --full"
echo -e "  8. ${BLUE}Wire delta hook${NC} : cp docs/templates/husky-pre-commit.sh .husky/pre-commit && chmod +x .husky/pre-commit"
echo -e "  9. ${BLUE}Wire CI cron${NC}   : cp docs/templates/scan-secu-weekly.yml .github/workflows/"
echo -e "  10. ${BLUE}Wire allowlist${NC} : cp docs/templates/.gitleaks.toml . (edit paths)"
echo ""
echo -e "${YELLOW}Doc canonical${NC} : docs/claude-config/experts.md (catalogue roles/ + stacks/adonisjs/)"
echo -e "${YELLOW}Discipline${NC}   : docs/lessons.md §1 (Karpathy 4)"
echo ""
