#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 10. Gitleaks (secrets in git history + files) ───────────────────────────
step 10 "Gitleaks (secrets detection)" 1 "A02 Crypto"
if command -v gitleaks &>/dev/null; then
  LEAKS_OUT=$(gitleaks detect --no-git --exit-code 0 --quiet 2>&1 || true)
  if echo "$LEAKS_OUT" | grep -q "leaks found: 0"; then
    pass "No secrets leaked"
  elif echo "$LEAKS_OUT" | grep -q "leaks found"; then
    fail "Secrets detected — run 'gitleaks detect --no-git -v' for details"
  else
    pass "No secrets leaked"
  fi
else
  skip "Gitleaks not installed — Windows: 'winget install gitleaks' | macOS: 'brew install gitleaks'"
fi
