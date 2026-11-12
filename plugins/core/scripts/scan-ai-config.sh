#!/usr/bin/env bash
# ============================================================================
# scan-ai-config.sh — Scan Claude Code AI config du projet vs standards cookbook
#
# Usage :
#   bash scan-ai-config.sh [path]           # scan + rapport human-readable
#   bash scan-ai-config.sh [path] --json    # sortie JSON pour parsing skill
#
# Standards checkés : 15 items, tiered P0 (bloquant) / P1 (recommandé) / P2 (nice).
# Verdict par item : PRESENT / MISSING / PARTIAL.
# Aucune modification du projet — read-only.
# ============================================================================

set -euo pipefail

TARGET="${1:-.}"
[ "$TARGET" = "--json" ] && { TARGET="."; JSON=1; } || JSON="${JSON:-0}"
[ "${2:-}" = "--json" ] && JSON=1
TARGET="$(cd "$TARGET" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

# Résultats : arrays parallèles item_name | tier | status | evidence
NAMES=(); TIERS=(); STATUSES=(); EVIDENCES=()

check() {
  local name="$1" tier="$2" path="$3" require="${4:-}"
  local full="$TARGET/$path"
  local status="MISSING" evidence="not found : $path"

  if [ -e "$full" ]; then
    if [ -z "$require" ]; then
      status="PRESENT"; evidence="found : $path"
    else
      if grep -qE "$require" "$full" 2>/dev/null; then
        status="PRESENT"; evidence="found + content OK : $path"
      else
        status="PARTIAL"; evidence="found but missing required content ($require) : $path"
      fi
    fi
  fi

  NAMES+=("$name"); TIERS+=("$tier"); STATUSES+=("$status"); EVIDENCES+=("$evidence")
}

check_dir_nonempty() {
  local name="$1" tier="$2" path="$3"
  local full="$TARGET/$path"
  local status="MISSING" evidence="dir absent or empty : $path"

  if [ -d "$full" ] && [ -n "$(ls -A "$full" 2>/dev/null || true)" ]; then
    local count=$(find "$full" -type f 2>/dev/null | wc -l | tr -d ' ')
    status="PRESENT"; evidence="$count file(s) in $path"
  elif [ -d "$full" ]; then
    status="PARTIAL"; evidence="dir exists but empty : $path"
  fi

  NAMES+=("$name"); TIERS+=("$tier"); STATUSES+=("$status"); EVIDENCES+=("$evidence")
}

# ── P0 (bloquant) — foundation Claude Code ─────────────────────────────────
check           "CLAUDE.md (project instructions)"       "P0" "CLAUDE.md" "§[0-9]+|# §"
check_dir_nonempty ".claude/agents/ (any expert)"        "P0" ".claude/agents"
check           "settings.json (Claude Code config)"      "P0" "settings.json"
# Fallback : accept .claude/settings.json aussi
if [ ! -f "$TARGET/settings.json" ] && [ -f "$TARGET/.claude/settings.json" ]; then
  for i in "${!NAMES[@]}"; do
    if [ "${NAMES[$i]}" = "settings.json (Claude Code config)" ]; then
      STATUSES[$i]="PRESENT"; EVIDENCES[$i]="found equivalent : .claude/settings.json"
    fi
  done
fi

# ── P1 (recommandé) — operating + docs foundation ──────────────────────────
check           "AGENTS.md (Claude operating manual)"    "P1" "AGENTS.md"
check           "PRODUCT.md (product vision)"             "P1" "PRODUCT.md" ""
# Vision peut aussi être dans docs/vision.md
if [ ! -f "$TARGET/PRODUCT.md" ] && [ -f "$TARGET/docs/vision.md" ]; then
  # Override : marquer PRODUCT.md PRESENT si docs/vision.md existe
  for i in "${!NAMES[@]}"; do
    if [ "${NAMES[$i]}" = "PRODUCT.md (product vision)" ]; then
      STATUSES[$i]="PRESENT"; EVIDENCES[$i]="found equivalent : docs/vision.md"
    fi
  done
fi
check           "docs/architecture.md"                    "P1" "docs/architecture.md"
check           "docs/anti-patterns.md"                   "P1" "docs/anti-patterns.md"
check           "docs/lessons.md"                         "P1" "docs/lessons.md"
check           ".mcp.json (MCP servers config)"          "P1" ".mcp.json"
check_dir_nonempty ".claude/skills/ (any skill)"         "P1" ".claude/skills"
check_dir_nonempty ".claude/hooks/ (any hook)"           "P1" ".claude/hooks"
check           "scan-secu.sh"                           "P1" "scan-secu.sh"

# ── P2 (nice) — qualité + governance ───────────────────────────────────────
check           "docs/feature-plan-template.md"          "P2" "docs/feature-plan-template.md"
check           "commitlint.config.js"                   "P2" "commitlint.config.js"
check           "lefthook.yml"                           "P2" "lefthook.yml"
check_dir_nonempty ".github/workflows/ (CI)"            "P2" ".github/workflows"

# ── Sortie ─────────────────────────────────────────────────────────────────
if [ "$JSON" = "1" ]; then
  echo "{"
  echo "  \"target\": \"$TARGET\","
  echo "  \"items\": ["
  last=$((${#NAMES[@]} - 1))
  for i in "${!NAMES[@]}"; do
    printf '    {"name": %s, "tier": "%s", "status": "%s", "evidence": %s}' \
      "$(printf '%s' "${NAMES[$i]}" | jq -Rs .)" \
      "${TIERS[$i]}" "${STATUSES[$i]}" \
      "$(printf '%s' "${EVIDENCES[$i]}" | jq -Rs .)"
    [ "$i" -lt "$last" ] && echo "," || echo ""
  done
  echo "  ]"
  echo "}"
else
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  Scan AI Config Claude Code${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "  Target : ${BLUE}${TARGET}${NC}"
  echo ""

  local_present=0; local_partial=0; local_missing=0
  for tier in P0 P1 P2; do
    label="P0 — Foundation (bloquant)"
    [ "$tier" = "P1" ] && label="P1 — Recommandé"
    [ "$tier" = "P2" ] && label="P2 — Nice-to-have"
    echo -e "${BOLD}${label}${NC}"
    for i in "${!NAMES[@]}"; do
      [ "${TIERS[$i]}" = "$tier" ] || continue
      case "${STATUSES[$i]}" in
        PRESENT) icon="${GREEN}✓${NC}" ; local_present=$((local_present+1)) ;;
        PARTIAL) icon="${YELLOW}⚠${NC}"; local_partial=$((local_partial+1)) ;;
        MISSING) icon="${RED}✗${NC}"  ; local_missing=$((local_missing+1)) ;;
      esac
      printf "  %b %s\n     └─ %s\n" "$icon" "${NAMES[$i]}" "${EVIDENCES[$i]}"
    done
    echo ""
  done

  total=${#NAMES[@]}
  echo -e "${BOLD}Résumé${NC} : ${GREEN}${local_present}${NC} present / ${YELLOW}${local_partial}${NC} partial / ${RED}${local_missing}${NC} missing (total $total)"

  # Verdict global
  p0_missing=0
  for i in "${!NAMES[@]}"; do
    [ "${TIERS[$i]}" = "P0" ] && [ "${STATUSES[$i]}" != "PRESENT" ] && p0_missing=$((p0_missing+1))
  done
  echo ""
  if [ "$p0_missing" -gt 0 ]; then
    echo -e "${RED}${BOLD}Verdict : NEEDS BOOTSTRAP${NC} — $p0_missing item(s) P0 manquant(s). Lancer /ai-config scaffold."
    exit 2
  elif [ "$local_missing" -gt 0 ] || [ "$local_partial" -gt 0 ]; then
    echo -e "${YELLOW}${BOLD}Verdict : PARTIAL${NC} — foundation OK, gap P1/P2. Lancer /ai-config scaffold pour compléter."
    exit 1
  else
    echo -e "${GREEN}${BOLD}Verdict : COMPLET${NC} — tous les standards Claude Code sont présents."
    exit 0
  fi
fi
