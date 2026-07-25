#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 10. Gitleaks (secrets — working tree + FULL git history) ──────────────
# NB : bug 2026-07-22 — l'ancienne version utilisait --no-git = SKIP l'history.
# Un .env.bak leaké dans un ancien commit (retiré HEAD) restait invisible :
# working tree clean mais history contient toujours le fichier. Fix : scan
# double — (a) working tree rapide, (b) full history obligatoire.
# En diff mode : gitleaks protect --staged (delta only, ~1s) — full history
# check reste au --full pre-push + cron hebdo.
step 10 "Gitleaks (secrets — working tree + git history)" 1 "A02 Crypto"
if [ "$MODE" = "diff" ]; then
  if command -v gitleaks &>/dev/null; then
    if [ "${SECU_DIFF_STAGED:-0}" = "1" ]; then
      GL_OUT=$(gitleaks protect --staged --exit-code 0 2>&1 || true)
    else
      GL_OUT=$(gitleaks git --exit-code 0 --log-opts="${DIFF_BASE:-HEAD~1}..HEAD" 2>&1 || true)
    fi
    GL_LEAKS=$(echo "$GL_OUT" | grep -oE "leaks found: [0-9]+" 2>/dev/null | grep -oE "[0-9]+" 2>/dev/null | tail -1 || true)
    GL_LEAKS=${GL_LEAKS:-0}
    if [ "$GL_LEAKS" = "0" ]; then
      pass "No secrets in delta (full history scan → pre-push --full)"
    else
      fail "Secrets in delta ($GL_LEAKS) — retire les avant commit"
    fi
  else
    skip "gitleaks not installed"
  fi
elif command -v gitleaks &>/dev/null; then
  # gitleaks v8.28+ : subcommands renommés (`git` remplace `detect` avec history,
  # `dir` remplace `detect --no-git`). Fallback vers ancienne API si version < 8.28.
  if gitleaks git --help &>/dev/null; then
    WT_CMD="gitleaks dir --exit-code 0"
    HIST_ALL_CMD="gitleaks git --exit-code 0 --log-opts=--all"
  else
    WT_CMD="gitleaks detect --no-git --exit-code 0"
    HIST_ALL_CMD="gitleaks detect --exit-code 0 --log-opts=--all"
  fi
  WT_OUT=$($WT_CMD 2>&1 || true)
  HIST_OUT=$($HIST_ALL_CMD 2>&1 || true)
  WT_LEAKS=$(echo "$WT_OUT" | grep -oE "leaks found: [0-9]+" 2>/dev/null | grep -oE "[0-9]+" 2>/dev/null | tail -1 || true)
  HIST_LEAKS=$(echo "$HIST_OUT" | grep -oE "leaks found: [0-9]+" 2>/dev/null | grep -oE "[0-9]+" 2>/dev/null | tail -1 || true)
  WT_LEAKS=${WT_LEAKS:-0}
  HIST_LEAKS=${HIST_LEAKS:-0}
  if [[ "$WT_LEAKS" == "0" && "$HIST_LEAKS" == "0" ]]; then
    pass "No secrets leaked (working tree + git history all-refs clean)"
  elif [[ "$WT_LEAKS" != "0" && "$HIST_LEAKS" != "0" ]]; then
    fail "Secrets detected — WORKING TREE ($WT_LEAKS) + GIT HISTORY ($HIST_LEAKS). Run '$HIST_ALL_CMD -v' + purge via 'git filter-repo --path <file> --invert-paths --force'"
  elif [[ "$WT_LEAKS" != "0" ]]; then
    fail "Secrets detected in WORKING TREE ($WT_LEAKS) — run '$WT_CMD -v'. Considère '.gitleaks.toml' pour allowlist test fixtures / local dev files."
  else
    fail "Secrets detected in GIT HISTORY all-refs ($HIST_LEAKS) — run '$HIST_ALL_CMD -v' + purge via 'git filter-repo --path <file> --invert-paths --force'"
  fi
else
  skip "Gitleaks not installed — Windows: 'winget install gitleaks' | macOS: 'brew install gitleaks'"
fi
