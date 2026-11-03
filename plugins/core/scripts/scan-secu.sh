#!/usr/bin/env bash
# ============================================================================
# Pre-push Security & Quality Scan — modular orchestrator
#
# Run before every commit/push to ensure code is clean, secure, and buildable.
# Usage: npm run scan   (Git Bash on Windows / bash on macOS/Linux)
#
# Optional tools:
#   Windows: winget install aquasecurity.trivy  |  winget install gitleaks
#   macOS:   brew install trivy                  |  brew install gitleaks
#
# Architecture (cookbook v0.2):
#   - This file is the orchestrator: shared state (counters, TIER context,
#     TOP_RISKS), helper functions (step/pass/fail/warn), summary + verdict.
#   - Each individual check lives in scripts/scan-secu.d/step-NN-<slug>.sh
#     and is sourced in numeric order. Steps are stateless greps that call
#     the helpers — orchestrator holds the cross-step state.
#   - Add a new check : drop a `step-NN-<slug>.sh` file in scan-secu.d/.
#     Total step count is computed at runtime, no orchestrator edit needed.
# ============================================================================

set -euo pipefail

# `**` recursif portable (off par defaut sur macOS/Linux) — requis par les
# globs `app/controllers/**/*.ts` des checks IDOR / SoftDelete / TenantSeam.
# Sans ca `**` se degrade en `*`.
# Garde-fou bash 3.2 (macOS /usr/bin/env bash) : `shopt -s globstar` est
# inconnu et explose sous `set -e`. Degradation gracieuse avec WARN explicite
# plutot que crasher avant la premiere etape.
if ! shopt -s globstar 2>/dev/null; then
  printf '[scan-secu] WARN: bash %s detected — globstar unavailable, "**" degrades to "*". Install bash 4+ (brew install bash) for future-proof recursive coverage.\n' "${BASH_VERSION%%(*}" >&2
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# ── Cross-step state (mutated by helpers below) ────────────────────────────
PASS=0
FAIL=0
WARN=0

# Per-tier counters (bash 3.2 compat — no associative arrays)
T1_PASS=0; T1_FAIL=0; T1_WARN=0  # BLOCKER (A01 Access / A02 Crypto / A03 Injection / A04 Insecure Design)
T2_PASS=0; T2_FAIL=0; T2_WARN=0  # IMPORTANT (A05 Misconfig / A07 Auth / A09 Logging)
T3_PASS=0; T3_FAIL=0; T3_WARN=0  # ADVISORY (Supply chain / Code quality / Conventions)

# Current step tier context (set by step(), read by pass/fail/warn)
TIER=3
GROUP="Quality"
CURRENT_STEP=""
TOP_RISKS=""  # newline-separated "T<n> · <group> — <message>" entries for summary

# ── Helper functions (called by step files via `source`) ───────────────────
step() {
  TIER="${3:-3}"
  GROUP="${4:-Quality}"
  CURRENT_STEP="$2"
  echo -e "\n${BLUE}${BOLD}[$1/${TOTAL}]${NC} ${BOLD}$2${NC} ${YELLOW}[T${TIER} · ${GROUP}]${NC}"
}
pass() {
  echo -e "  ${GREEN}PASS${NC} $1"; PASS=$((PASS + 1))
  case "$TIER" in 1) T1_PASS=$((T1_PASS + 1));; 2) T2_PASS=$((T2_PASS + 1));; *) T3_PASS=$((T3_PASS + 1));; esac
}
fail() {
  echo -e "  ${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1))
  case "$TIER" in 1) T1_FAIL=$((T1_FAIL + 1));; 2) T2_FAIL=$((T2_FAIL + 1));; *) T3_FAIL=$((T3_FAIL + 1));; esac
  TOP_RISKS="${TOP_RISKS}T${TIER} · ${GROUP} — ${CURRENT_STEP}: $1"$'\n'
}
warn() {
  echo -e "  ${YELLOW}WARN${NC} $1"; WARN=$((WARN + 1))
  case "$TIER" in 1) T1_WARN=$((T1_WARN + 1));; 2) T2_WARN=$((T2_WARN + 1));; *) T3_WARN=$((T3_WARN + 1));; esac
  # Track tier 1/2 warnings as risks (tier 3 warnings are dette — not blocking insights)
  if [ "${TIER:-3}" -le 2 ]; then
    TOP_RISKS="${TOP_RISKS}T${TIER} · ${GROUP} ⚠ — ${CURRENT_STEP}: $1"$'\n'
  fi
}
skip() { echo -e "  ${YELLOW}SKIP${NC} $1"; }

# Banner: marque la transition entre tiers — non utilise dans le pipeline
# actuel mais expose pour usage futur (par ex. orchestrateur partiel).
tier_banner() {
  echo ""
  echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
  echo -e "  ${BOLD}TIER $1 — $2${NC}"
  echo -e "  ${YELLOW}$3${NC}"
  echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
}

# ── Resolve script dir + step modules ───────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Steps core : à côté du script (cookbook, ou scripts/ cible) ou, si le script
# est copié à la racine d'un projet, dans scripts/scan-secu.d.
if [ -d "$SCRIPT_DIR/scan-secu.d" ]; then
  STEPS_DIR="$SCRIPT_DIR/scan-secu.d"
else
  STEPS_DIR="$SCRIPT_DIR/scripts/scan-secu.d"
fi
if [ ! -d "$STEPS_DIR" ]; then
  echo -e "${RED}ERROR: scan-secu.d/ introuvable (cherché dans $SCRIPT_DIR et $SCRIPT_DIR/scripts).${NC}" >&2
  exit 2
fi

# Steps additionnels (packs de stack) : SECU_EXTRA_STEPS_DIRS="dir1:dir2".
# Après bootstrap, les steps du pack sont déjà fusionnés dans STEPS_DIR.
# Tous les steps sont exécutés triés par nom de fichier, quel que soit leur dossier.
STEP_FILES=$(
  {
    find "$STEPS_DIR" -maxdepth 1 -name 'step-*.sh' -type f
    IFS=':' read -r -a _extra_dirs <<< "${SECU_EXTRA_STEPS_DIRS:-}"
    for d in "${_extra_dirs[@]:-}"; do
      if [ -n "$d" ] && [ -d "$d" ]; then
        find "$d" -maxdepth 1 -name 'step-*.sh' -type f
      fi
    done
  } | awk -F/ '{print $NF "\t" $0}' | sort | cut -f2-
)

# TOTAL = nombre de steps trouvés : ajouter un fichier step-*.sh l'incrémente
# sans toucher cet orchestrateur.
TOTAL=$(printf '%s\n' "$STEP_FILES" | grep -c . || true)

# ─── CLI mode: --full (default) | --diff [<base>] ─────────────────────────
# --diff : skip global-scope steps (build/typecheck/npm audit/Trivy/SBOM…) and
# filter per-file scans to only files changed since <base> (default HEAD~1 en
# post-commit, --cached en pre-commit via SECU_DIFF_STAGED=1).
# Objectif : pre-commit hook rapide (<10s) qui bloque la dette au moment où
# elle est écrite, complète le --full pre-push (2-3min) + cron hebdo CI.
MODE="full"
DIFF_BASE=""
for arg in "$@"; do
  case "$arg" in
    --diff) MODE="diff" ;;
    --diff=*) MODE="diff"; DIFF_BASE="${arg#--diff=}" ;;
    --full) MODE="full" ;;
    --help|-h)
      echo "Usage: scan-secu.sh [--full|--diff[=<base-sha>]]"
      echo "  --full          Scan complet (défaut, pre-push + CI hebdo)"
      echo "  --diff          Scan seulement fichiers changés (pre-commit, ~10s)"
      echo "  --diff=<sha>    Base explicite (défaut HEAD~1, --cached si SECU_DIFF_STAGED=1)"
      exit 0
      ;;
  esac
done

CHANGED_FILES=""
if [ "$MODE" = "diff" ]; then
  if [ "${SECU_DIFF_STAGED:-0}" = "1" ]; then
    CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACMRT 2>/dev/null || true)
    DIFF_LABEL="git diff --cached (staged)"
  else
    BASE="${DIFF_BASE:-HEAD~1}"
    CHANGED_FILES=$(git diff --name-only --diff-filter=ACMRT "$BASE" 2>/dev/null || true)
    DIFF_LABEL="${BASE}..HEAD"
  fi
  CHANGED_COUNT=$(echo "$CHANGED_FILES" | grep -c . || true)
  echo -e "${BOLD}[scan-secu:diff] ${CHANGED_COUNT} file(s) changed vs ${DIFF_LABEL}${NC}"
  if [ "$CHANGED_COUNT" = "0" ]; then
    echo -e "  ${GREEN}No changes to scan — exit clean.${NC}"
    exit 0
  fi
fi

# Helper : skip step in diff mode (global-scope scans that can't be delta-ised).
# Usage inside a step file :
#   if ! skip_if_diff; then
#     ... expensive scan (build, typecheck, Trivy, SBOM, license, deps outdated) ...
#   fi
skip_if_diff() {
  if [ "$MODE" = "diff" ]; then
    skip "delta mode — full-scope check, run 'scan-secu.sh --full' pre-push"
    return 0
  fi
  return 1
}

# Helper : return 0 (true) if diff mode + at least one changed file matches pattern.
# Steps whose scope is a specific directory (app/controllers, resources/lang) can
# short-circuit when nothing relevant was touched.
#   Usage : if [ "$MODE" = "diff" ] && ! has_changed_matching "^app/(controllers|services)/"; then
#             skip "no controllers/services touched — full sweep pre-push"; return; fi
has_changed_matching() {
  if [ "$MODE" != "diff" ]; then return 0; fi
  echo "$CHANGED_FILES" | grep -qE "$1"
}

echo -e "${BOLD}============================================${NC}"
echo -e "${BOLD}  Pre-push Security Scan${NC}"
echo -e "${BOLD}============================================${NC}"

# ── Run all steps in numeric order ──────────────────────────────────────────
# Each step file is sourced (not exec'd) so it sees the helpers + state.
# shellcheck disable=SC1090
STEP_ARR=()
while IFS= read -r _f; do [ -n "$_f" ] && STEP_ARR+=("$_f"); done <<< "$STEP_FILES"
for step_file in "${STEP_ARR[@]}"; do
  [ -f "$step_file" ] || continue
  source "$step_file"
done

# ════════════════════════════════════════════════════════════════════════════
# Summary — graduated by tier + top risks
# ════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
echo -e "  ${BOLD}Pre-push Security Scan — Tier Summary${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
printf "  ${RED}${BOLD}TIER 1 BLOCKER${NC}    %s   ${GREEN}PASS %2d${NC}  ${RED}FAIL %2d${NC}  ${YELLOW}WARN %2d${NC}\n" \
  "(A01/A02/A03/A04)" $T1_PASS $T1_FAIL $T1_WARN
printf "  ${YELLOW}${BOLD}TIER 2 IMPORTANT${NC}  %s        ${GREEN}PASS %2d${NC}  ${RED}FAIL %2d${NC}  ${YELLOW}WARN %2d${NC}\n" \
  "(A05/A07/A09)" $T2_PASS $T2_FAIL $T2_WARN
printf "  ${BLUE}${BOLD}TIER 3 ADVISORY${NC}   %s         ${GREEN}PASS %2d${NC}  ${RED}FAIL %2d${NC}  ${YELLOW}WARN %2d${NC}\n" \
  "(Supply / Quality / Conv)" $T3_PASS $T3_FAIL $T3_WARN
echo -e "${BOLD}─────────────────────────────────────────────────────────────────────${NC}"
printf "  ${BOLD}TOTAL${NC}            ${GREEN}PASS: %2d${NC}  ${RED}FAIL: %2d${NC}  ${YELLOW}WARN: %2d${NC}\n" $PASS $FAIL $WARN
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"

# Top risks open (T1+T2 only — T3 warn = dette, pas insight actionnable)
if [ -n "$TOP_RISKS" ]; then
  echo ""
  echo -e "${BOLD}Top risks open (Tier 1+2):${NC}"
  printf '%s' "$TOP_RISKS" | head -8 | while IFS= read -r line; do
    [ -n "$line" ] && echo -e "  ${RED}•${NC} $line"
  done
fi

# Verdict graduel : T1 FAIL = BLOCKED. T2 FAIL = NEEDS REVIEW. T3 only FAIL = SHIP with debt.
echo ""
if [ $T1_FAIL -gt 0 ]; then
  echo -e "${RED}${BOLD}🔴 BLOCKED${NC} — $T1_FAIL Tier-1 BLOCKER fail(s). Fix before push (data leak / RCE risk)."
  exit 1
elif [ $T2_FAIL -gt 0 ]; then
  echo -e "${YELLOW}${BOLD}🟡 NEEDS REVIEW${NC} — $T2_FAIL Tier-2 IMPORTANT fail(s). Fix before merge."
  exit 1
elif [ $FAIL -gt 0 ]; then
  echo -e "${YELLOW}${BOLD}🟡 SHIP WITH DEBT${NC} — $FAIL Tier-3 ADVISORY fail(s). Track in roadmap."
  exit 1
else
  echo -e "${GREEN}${BOLD}🟢 READY TO PUSH${NC}"
  exit 0
fi
