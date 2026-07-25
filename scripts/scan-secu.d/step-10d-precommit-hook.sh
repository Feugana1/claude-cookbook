#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 10d. Guard : pre-commit hook installé (husky ou natif) ────────────────
# Pre-commit hook = premier rempart delta (bloque secret/lint/type avant commit).
# Sans hook, le user peut committer sans que scan-secu tourne — dette accumulée
# silencieusement jusqu'au pre-push (trop tard = context perdu).
step 10d "Pre-commit hook installed" 2 "A05 Misconfig"
if [ -x .husky/pre-commit ] || [ -x .git/hooks/pre-commit ]; then
  pass "Pre-commit hook active"
else
  warn "No pre-commit hook — commits ne trigger PAS scan-secu/lint-staged. Install : 'npm i -D husky && npx husky init' puis ajouter 'SECU_DIFF_STAGED=1 bash scan-secu.sh --diff' dans .husky/pre-commit"
fi
