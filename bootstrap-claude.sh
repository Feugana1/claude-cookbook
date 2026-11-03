#!/usr/bin/env bash
# ============================================================================
# bootstrap-claude.sh — Copie le cookbook Claude vers un projet cible
#
# Usage:
#   bash bootstrap-claude.sh <path-to-project> [--stack=none|adonisjs] [--update]
#
#   --stack=none       (defaut CI non-TTY) : installe tous les roles/ génériques
#   --stack=adonisjs   : installe les roles/ non remplacés + stacks/adonisjs/ (sans redondance)
#   --update           : preserve fichiers projet-specific (CLAUDE.md, agents custom, etc.)
#
# Sans --stack et en TTY interactif : prompt menu.
# Voir plugins/adonisjs/README.md pour le mapping override roles ↔ stacks.
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
CORE="$COOKBOOK_ROOT/plugins/core"          # générique, toujours installé

if [ $# -lt 1 ]; then
  echo -e "${RED}Usage: bash bootstrap-claude.sh <path-to-project> [--stack=none|adonisjs] [--update]${NC}"
  echo ""
  echo "Examples:"
  echo "  bash bootstrap-claude.sh ~/code/my-new-saas"
  echo "  bash bootstrap-claude.sh ~/code/my-adonis --stack=adonisjs"
  echo "  bash bootstrap-claude.sh . --update"
  exit 1
fi

TARGET="$(cd "$1" && pwd)"
shift
UPDATE_MODE=false
STACK=""
for arg in "$@"; do
  case "$arg" in
    --update) UPDATE_MODE=true ;;
    --stack=*) STACK="${arg#--stack=}" ;;
    *) echo -e "${YELLOW}Warn : arg inconnu ignoré : $arg${NC}" ;;
  esac
done

if [ ! -d "$TARGET" ]; then
  echo -e "${RED}Target directory does not exist: $TARGET${NC}"
  exit 1
fi

# ── Résolution du mode stack ────────────────────────────────────────────────
# Sources de vérité mapping : plugins/adonisjs/README.md
# Mode `none`     : tous les roles/ (générique cross-stack)
# Mode `adonisjs` : roles/ non remplacés + stacks/adonisjs/
#   Roles conservés : analyzer, frontend, performance, product-strategist, qa
#   Roles remplacés : architect (→ back-architect) ; reviewer (→ code-reviewer) ;
#                     security (→ security-multitenant)
ROLES_ADONISJS_KEPT=(analyzer frontend performance product-strategist qa)

if [ -z "$STACK" ]; then
  if [ -t 0 ] && [ -t 1 ]; then
    echo ""
    echo -e "${BOLD}Choisir la stack cible :${NC}"
    echo "  1) none      — rôles génériques (cross-stack universel)"
    echo "  2) adonisjs  — rôles génériques non remplacés + experts stack AdonisJS durcis (zero redondance)"
    echo ""
    read -r -p "Ton choix [1/2] (defaut 1) : " choice
    case "${choice:-1}" in
      2|adonisjs) STACK="adonisjs" ;;
      *)          STACK="none" ;;
    esac
  else
    STACK="none"  # non-TTY (CI) : défaut safe
  fi
fi

case "$STACK" in
  none|adonisjs) ;;
  *) echo -e "${RED}Stack invalide : $STACK (attendu : none|adonisjs)${NC}"; exit 1 ;;
esac

PACK="$COOKBOOK_ROOT/plugins/$STACK"

echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Claude Cookbook → Bootstrap${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "  Source : ${BLUE}${COOKBOOK_ROOT}${NC}"
echo -e "  Target : ${BLUE}${TARGET}${NC}"
echo -e "  Mode   : ${YELLOW}$([ "$UPDATE_MODE" = true ] && echo "UPDATE (preserve project-specific files)" || echo "INIT (fresh setup)")${NC}"
echo -e "  Stack  : ${YELLOW}${STACK}${NC}"
echo ""

# ── Préparer arborescence cible ─────────────────────────────────────────────
mkdir -p "$TARGET/.claude/agents/roles"
mkdir -p "$TARGET/.claude/skills"
mkdir -p "$TARGET/.claude/hooks"
mkdir -p "$TARGET/scripts"
mkdir -p "$TARGET/docs/claude-config"
[ "$STACK" = "adonisjs" ] && mkdir -p "$TARGET/.claude/agents/stacks/adonisjs"

# ── Copier les agents (install sélectif selon $STACK) ──────────────────────
# Source de vérité mapping : plugins/adonisjs/README.md
if [ "$STACK" = "none" ]; then
  echo -e "${GREEN}[1/6]${NC} Agents (roles/ génériques — mode generic cross-stack)..."
  for f in "$CORE"/agents/*.md; do
    cp "$f" "$TARGET/.claude/agents/roles/"
    echo "    + roles/$(basename "$f")"
  done
else
  # Mode adonisjs : roles/ conservés + stacks/adonisjs/ (les 4 roles remplacés — architect/backend/reviewer/security — ne sont PAS copiés)
  echo -e "${GREEN}[1/6]${NC} Agents (roles/ non remplacés + stacks/adonisjs/, mode adonisjs)..."
  for name in "${ROLES_ADONISJS_KEPT[@]}"; do
    src="$CORE/agents/${name}.md"
    if [ -f "$src" ]; then
      cp "$src" "$TARGET/.claude/agents/roles/"
      echo "    + roles/${name}.md"
    fi
  done
  for f in "$PACK"/agents/*.md; do
    cp "$f" "$TARGET/.claude/agents/stacks/adonisjs/"
    echo "    + stacks/adonisjs/$(basename "$f")"
  done
  echo -e "    ${YELLOW}Roles remplacés (non copiés) : architect, backend (→ back-architect), reviewer (→ code-reviewer), security (→ security-multitenant)${NC}"
fi

# ── Copier les skills + commands ──────────────────────────────────
# NB strip trailing slash sinon macOS BSD cp copie le CONTENU au lieu du dossier
echo -e "${GREEN}[2/6]${NC} Skills + commands..."
SKILL_DIRS=("$CORE"/skills/*/)
[ "$STACK" = "adonisjs" ] && SKILL_DIRS+=("$PACK"/skills/*/)
for dir in "${SKILL_DIRS[@]}"; do
  skillname=$(basename "$dir")
  cp -r "${dir%/}" "$TARGET/.claude/skills/"
  echo "    + skill /$skillname"
done
mkdir -p "$TARGET/.claude/commands"
for f in "$CORE"/commands/*.md; do
  cp "$f" "$TARGET/.claude/commands/"
  echo "    + command /$(basename "$f" .md)"
done

# ── Copier les hooks ────────────────────────────────────────────────────────
echo -e "${GREEN}[3/6]${NC} Hooks..."
for f in "$CORE"/hooks/*.sh; do
  cp "$f" "$TARGET/.claude/hooks/"
  echo "    + $(basename "$f")"
done
if [ "$STACK" = "adonisjs" ]; then
  for f in "$PACK"/hooks/*.sh; do
    cp "$f" "$TARGET/.claude/hooks/"
    echo "    + $(basename "$f") (pack adonisjs)"
  done
fi
chmod +x "$TARGET/.claude/hooks/"*.sh

# ── Copier les scripts qualité ──────────────────────────────────────────────
echo -e "${GREEN}[4/6]${NC} Scripts qualité..."
cp "$CORE/scripts/scan-secu.sh" "$TARGET/scan-secu.sh"
chmod +x "$TARGET/scan-secu.sh"
mkdir -p "$TARGET/scripts/scan-secu.d"
cp "$CORE"/scripts/scan-secu.d/*.sh "$TARGET/scripts/scan-secu.d/"
echo "    + scan-secu.sh (root) + scripts/scan-secu.d/ (steps génériques)"
if [ "$STACK" = "adonisjs" ]; then
  cp "$PACK"/scripts/scan-secu.d/*.sh "$TARGET/scripts/scan-secu.d/"
  cp "$PACK/scripts/check-file-sizes.js" "$TARGET/scripts/"
  echo "    + steps scan-secu du pack adonisjs + scripts/check-file-sizes.js"
fi
for f in generate-sbom.sh statusline.sh scan-ai-config.sh scan-prod-readiness.sh; do
  cp "$CORE/scripts/$f" "$TARGET/scripts/"
  chmod +x "$TARGET/scripts/$f"
  echo "    + scripts/$f"
done

# ── Copier la doc ───────────────────────────────────────────────────────────
echo -e "${GREEN}[5/6]${NC} Docs Claude..."
cp "$COOKBOOK_ROOT/docs/lessons.md" "$TARGET/docs/"
cp "$COOKBOOK_ROOT/docs/anti-patterns.md" "$TARGET/docs/"
cp "$COOKBOOK_ROOT/docs/feature-plan-template.md" "$TARGET/docs/"
cp "$COOKBOOK_ROOT/docs/ux-audit-prompt.md" "$TARGET/docs/"
cp "$COOKBOOK_ROOT/docs/claude-config/experts.md" "$TARGET/docs/claude-config/"
if [ "$STACK" = "adonisjs" ]; then cp "$PACK/README.md" "$TARGET/docs/claude-config/stack-adonisjs.md"; fi
cp "$COOKBOOK_ROOT/docs/claude-config/setup.md" "$TARGET/docs/claude-config/"
# Templates scaffold /ai-config (copies non-écrasantes, l'user peut cp vers root/docs/ ensuite)
mkdir -p "$TARGET/docs/templates"
for t in AGENTS.md PRODUCT.md architecture.md mcp.json example-domain-agent.md CLAUDE.md husky-pre-commit.sh scan-secu-weekly.yml .gitleaks.toml; do
  [ -f "$COOKBOOK_ROOT/docs/templates/$t" ] && cp "$COOKBOOK_ROOT/docs/templates/$t" "$TARGET/docs/templates/"
done
if [ "$STACK" = "adonisjs" ] && [ -d "$PACK/docs" ]; then
  cp "$PACK"/docs/*.md "$TARGET/docs/"
  echo "    + docs du pack adonisjs ($(ls "$PACK"/docs | tr '\n' ' '))"
fi
echo "    + docs/lessons.md (Karpathy 4 + leçons)"
echo "    + docs/anti-patterns.md (générique ; catalogue stack fourni par le pack)"
echo "    + docs/feature-plan-template.md (~200L max)"
echo "    + docs/ux-audit-prompt.md (6 axes UX)"
echo "    + docs/claude-config/{experts,setup}.md (+ stack-adonisjs.md en mode adonisjs)"
echo "    + docs/templates/ (CLAUDE, AGENTS, PRODUCT, architecture, mcp.json, example-domain-agent + husky/scan-secu-weekly/.gitleaks)"

# ── Manifest plugin + settings.json + .mcp.json + config ────────────────────
echo -e "${GREEN}[6/6]${NC} settings.json + MCP + Conventional Commits config..."

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
echo -e "  • settings.json (permissions deny + hooks wire + env + statusLine — copié si absent)"
echo -e "  • .mcp.json (Context7 + sequential-thinking + fetch + github — copié si absent)"
echo -e "  • commitlint.config.js + lefthook.yml + .markdownlint.json (Conventional Commits + linting)"
_n() { find "$@" -type f 2>/dev/null | wc -l | tr -d ' '; }
N_AGENTS=$(_n "$TARGET/.claude/agents" -name '*.md')
N_SKILLS=$(find "$TARGET/.claude/skills" -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
N_CMDS=$(_n "$TARGET/.claude/commands" -name '*.md')
N_HOOKS=$(_n "$TARGET/.claude/hooks" -name '*.sh')
N_STEPS=$(_n "$TARGET/scripts/scan-secu.d" -name 'step-*.sh')
echo -e "  • ${N_AGENTS} sub-agents (.claude/agents/ — mode --stack=${STACK})"
echo -e "  • ${N_SKILLS} skills (.claude/skills/)"
echo -e "  • ${N_CMDS} commands (.claude/commands/)"
echo -e "  • ${N_HOOKS} hooks (.claude/hooks/)"
echo -e "  • scripts/ : scan-secu.sh + scan-secu.d/ (${N_STEPS} modules) + check-file-sizes.js + generate-sbom.sh + statusline.sh + scan-ai-config.sh + scan-prod-readiness.sh"
echo -e "  • docs/ : lessons, anti-patterns, feature-plan-template, ux-audit-prompt, claude-config/, templates/ (scaffold via /ai-config)"
if [ "$UPDATE_MODE" = false ]; then
  echo -e "  • CLAUDE.md (template — §5 Domain Model Glossary à remplir)"
fi
echo ""
echo -e "${BOLD}Next steps${NC} :"
echo -e "  1. ${BLUE}Éditer${NC} CLAUDE.md §5 Domain Model Glossary — lister PRIMARY_MODELS du projet"
echo -e "  2. ${BLUE}Éditer${NC} CLAUDE.md §1 Stack + §2 Conventions + §3 i18n"
echo -e "  3. ${BLUE}Export${NC} PRIMARY_MODELS_RE dans scripts/scan-secu.env (cf §5)"
echo -e "  4. ${BLUE}Ajouter${NC} agents domain-specific dans .claude/agents/stacks/<votre-stack>/ (ceux de stacks/adonisjs/ ciblent AdonisJS)"
echo -e "  5. ${BLUE}Première feature${NC} : invoquer subagent product-strategist via Agent tool"
echo -e "  6. ${BLUE}Avant commit${NC} : code-reviewer"
echo -e "  7. ${BLUE}Avant push${NC} : bash scan-secu.sh --full"
echo -e "  8. ${BLUE}Wire delta hook${NC} : cp docs/templates/husky-pre-commit.sh .husky/pre-commit && chmod +x .husky/pre-commit"
echo -e "  9. ${BLUE}Wire CI cron${NC}   : cp docs/templates/scan-secu-weekly.yml .github/workflows/"
echo -e "  10. ${BLUE}Wire allowlist${NC} : cp docs/templates/.gitleaks.toml . (edit paths)"
echo ""
echo -e "${YELLOW}Doc canonical${NC}   : docs/claude-config/experts.md (catalogue roles/ + stacks/adonisjs/)"
[ "$STACK" = "adonisjs" ] && echo -e "${YELLOW}Mapping stack${NC}   : docs/claude-config/stack-adonisjs.md (override roles ↔ pack)"
echo -e "${YELLOW}Discipline${NC}   : docs/lessons.md §1 (Karpathy 4)"
echo ""
