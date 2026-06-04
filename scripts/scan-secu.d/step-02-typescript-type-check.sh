#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 2. TypeScript type check ────────────────────────────────────────────────
step 2 "TypeScript type check" 3 "Code quality"
if npx tsc --noEmit 2>/dev/null; then
  pass "No type errors"
else
  fail "TypeScript errors — run 'npx tsc --noEmit' for details"
fi
