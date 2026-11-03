#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 1. ESLint + SonarJS ────────────────────────────────────────────────────
step 1 "ESLint + SonarJS" 3 "Code quality"
if [ "$MODE" = "diff" ]; then
  # Delta : lint only .ts/.js/.tsx changed files (fast pre-commit ~2s)
  ESLINT_TARGETS=$(echo "$CHANGED_FILES" | grep -E '\.(ts|tsx|js|jsx|mjs)$' 2>/dev/null | tr '\n' ' ' || true)
  if [ -z "$ESLINT_TARGETS" ]; then
    skip "no .ts/.js files changed"
  elif npx eslint --quiet $ESLINT_TARGETS 2>/dev/null; then
    pass "0 errors on $(echo $ESLINT_TARGETS | wc -w | tr -d ' ') changed file(s)"
  else
    fail "ESLint errors on changed files — run 'npx eslint --fix $ESLINT_TARGETS'"
  fi
else
  if npx eslint . --quiet 2>/dev/null; then
    pass "0 errors"
  else
    fail "ESLint errors — run 'npm run lint:fix' to auto-fix"
  fi
fi
