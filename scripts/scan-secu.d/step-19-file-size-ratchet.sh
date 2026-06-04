#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 19. File size ratchet (CLAUDE.md §14) ───────────────────────────────────
step 19 "File size ratchet (controllers 300 / services 400 / templates 800)" 3 "Code quality"
# NB : capturer le code retour réel — `$(cmd || true)` puis `$?` renvoie
# toujours 0 (exit du `true`), ce qui rendait cette étape toujours verte.
if RATCHET_OUT=$(node scripts/check-file-sizes.js 2>&1); then
  # Extract the shrunk lines from the output for the info-level feedback
  SHRUNK_LINE=$(echo "$RATCHET_OUT" | grep "baseline file(s) shrunk" || true)
  if [ -n "$SHRUNK_LINE" ]; then
    pass "All files within budget — $(echo "$SHRUNK_LINE" | sed 's/^[[:space:]]*✓ //')"
  else
    pass "All files within budget (see scripts/file-size-baseline.json)"
  fi
else
  fail "File size regression — run 'node scripts/check-file-sizes.js' for details"
  echo "$RATCHET_OUT" | grep -E '^\s+\S.*lines|^\s+\S.*→' | head -10 | while IFS= read -r line; do
    echo "    $line"
  done
fi
