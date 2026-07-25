#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 10c. Guard : .gitignore couvre les patterns .env* essentiels ──────────
# Post-mortem 2026-07-22 : .env.bak leak = .gitignore couvrait pas ce pattern
# au moment du commit. Un `.env.local` ou `.env.staging.local` créé + non
# ignoré = leak au prochain `git add .`. Cette étape audite proactivement.
step 10c "Guard .gitignore covers .env* patterns" 1 "A02 Crypto"
GITIGNORE_MISS=""
if [ ! -f .gitignore ]; then
  fail ".gitignore missing"
else
  # Patterns canoniques Node/dotenv — chaque ligne doit matcher exactement ou
  # via glob équivalent. `.env.*.local` couvre .env.staging.local etc.
  for p in ".env" ".env.local" ".env.*.local" ".env.bak" ".env.keys"; do
    if ! grep -qE "^${p}$" .gitignore 2>/dev/null; then
      GITIGNORE_MISS="${GITIGNORE_MISS}${p} "
    fi
  done
  if [ -z "$GITIGNORE_MISS" ]; then
    pass "All essential .env* patterns ignored"
  else
    fail ".gitignore manque patterns : $GITIGNORE_MISS— add them"
  fi
fi
