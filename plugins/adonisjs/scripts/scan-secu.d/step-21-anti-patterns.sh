#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 21. Project anti-patterns (CLAUDE.md §13 / docs/anti-patterns-adonisjs.md) ───────
step 21 "Project anti-patterns (Edge / Alpine)" 3 "Conventions"
# P0 — `||` dans @each : le mini-parseur @each tokenise `|` comme pipe → crash.
ANTI_EACH=$(grep -rn '@each(' resources/views/ --include="*.edge" 2>/dev/null | grep '||' || true)
# P1 — `{{{ }}}` dans x-data : utiliser <script type="application/json">.
ANTI_XDATA=$(grep -rn 'x-data=' resources/views/ --include="*.edge" 2>/dev/null | grep '{{{' || true)
ANTI_HITS=$(printf '%s\n%s\n' "$ANTI_EACH" "$ANTI_XDATA" | grep -E ':[0-9]+:' || true)
if [ -z "$ANTI_HITS" ]; then
  pass "No '||' in @each, no {{{ }}} in x-data"
else
  COUNT=$(echo "$ANTI_HITS" | wc -l | tr -d ' \r')
  fail "$COUNT Edge anti-pattern(s) — see docs/anti-patterns-adonisjs.md (Edge.js / Alpine.js)"
  echo "$ANTI_HITS" | head -5 | while IFS= read -r line; do echo "    $line"; done
fi
# WARN — anti-patterns pré-existants à migrer (n'échouent pas le scan).
STIMULUS=$(grep -rln 'data-controller="confirm"' resources/views/ --include="*.edge" 2>/dev/null || true)
if [ -n "$STIMULUS" ]; then
  SC=$(echo "$STIMULUS" | wc -l | tr -d ' \r')
  warn "$SC file(s) using data-controller=\"confirm\" — Stimulus non câblé, migrer vers Alpine 2-step"
fi
