#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 1. ESLint + SonarJS ────────────────────────────────────────────────────
step 1 "ESLint + SonarJS" 3 "Code quality"
if npx eslint . --quiet 2>/dev/null; then
  pass "0 errors"
else
  fail "ESLint errors — run 'npm run lint:fix' to auto-fix"
fi
