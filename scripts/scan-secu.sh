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
STEPS_DIR="$SCRIPT_DIR/scan-secu.d"
if [ ! -d "$STEPS_DIR" ]; then
  echo -e "${RED}ERROR: $STEPS_DIR missing — cookbook scan-secu.d/ directory not found.${NC}" >&2
  exit 2
fi

# TOTAL is the count of step files — adding a new step file under
# scan-secu.d/ auto-bumps it without touching this orchestrator.
TOTAL=$(find "$STEPS_DIR" -maxdepth 1 -name 'step-*.sh' -type f 2>/dev/null | wc -l | tr -d ' \r')

echo -e "${BOLD}============================================${NC}"
echo -e "${BOLD}  Pre-push Security Scan${NC}"
echo -e "${BOLD}============================================${NC}"

# ── Run all steps in numeric order ──────────────────────────────────────────
# Each step file is sourced (not exec'd) so it sees the helpers + state.
# shellcheck disable=SC1090
for step_file in "$STEPS_DIR"/step-*.sh; do
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
