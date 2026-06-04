#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 16. Build verification ──────────────────────────────────────────────────
step 16 "Build verification" 3 "Code quality"
if node ace build --ignore-ts-errors > /dev/null 2>&1; then
  pass "Build successful"
else
  fail "Build failed — run 'node ace build --ignore-ts-errors' for details"
fi
