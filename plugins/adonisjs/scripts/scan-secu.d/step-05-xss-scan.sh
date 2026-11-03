#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 5. XSS scan ────────────────────────────────────────────────────────────
step 5 "XSS scan (unescaped output)" 1 "A03 Injection"
XSS_ISSUES=$(grep -rn '{{{ ' resources/views/ --include="*.edge" 2>/dev/null \
  | grep -v 'sanitizeHtml\|ensureHtml\|safeJson\|JSON.stringify\|\$slots\|await \$slots\|csrfField\|vite\|@stack\|toAttrs' \
  | grep -v 'node_modules' || true)
if [ -z "$XSS_ISSUES" ]; then
  pass "All {{{ }}} outputs are sanitized"
else
  COUNT=$(echo "$XSS_ISSUES" | wc -l | tr -d ' \r')
  warn "$COUNT potential XSS — review {{{ }}} without sanitizeHtml/ensureHtml"
  echo "$XSS_ISSUES" | head -5 | while IFS= read -r line; do echo "    $line"; done
fi
