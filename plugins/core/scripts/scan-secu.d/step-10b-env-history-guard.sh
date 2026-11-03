#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 10b. Guard : jamais un .env* (hors .env.example/.env.test/*.example)
#          dans l'history git ────────────────────────────────────────────
# Post-mortem 2026-07-22 : `.env.bak` committé + retiré ne trigger PAS gitleaks
# working-tree. Cette étape check spécifiquement l'ADD d'un .env quelconque
# dans TOUT l'history, indépendamment de gitleaks patterns.
# En diff mode : check seulement staged/changed files (dette history scannée
# par --full pre-push + cron hebdo).
step 10b "Guard .env dans git history (add ever)" 1 "A02 Crypto"
if [ "$MODE" = "diff" ]; then
  ENV_DELTA=$(echo "$CHANGED_FILES" | grep -E "^\.env(\..*)?$" 2>/dev/null | grep -vE "^\.env\.(example|test)$|\.example$" 2>/dev/null || true)
  if [ -z "$ENV_DELTA" ]; then
    pass "No .env* in delta (history purge → pre-push --full)"
  else
    fail ".env* dans delta : $ENV_DELTA — retire avant commit"
  fi
else
  ENV_LEAKS=$(git log --all --diff-filter=A --name-only --pretty=format: 2>/dev/null \
    | grep -E "^\.env(\..*)?$" 2>/dev/null \
    | grep -vE "^\.env\.(example|test)$|\.example$" 2>/dev/null \
    | sort -u || true)
  if [[ -z "$ENV_LEAKS" ]]; then
    pass "No .env* file ever added to git history"
  else
    fail "Fichiers .env* committés dans l'history — purger via git filter-repo :"
    echo "$ENV_LEAKS" | while read -r f; do
      echo "  - $f (commits: $(git log --all --oneline --diff-filter=A -- "$f" | head -3 | awk '{print $1}' | tr '\n' ' '))"
    done
  fi
fi
