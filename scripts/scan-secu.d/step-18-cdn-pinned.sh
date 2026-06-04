#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 18. CDN versions in Edge templates ──────────────────────────────────────
step 18 "Unpinned CDN script/link URLs in Edge templates" 3 "Supply chain"
# Only check versioned script/style CDN hosts (exclude flagcdn.com: dynamic flag image urls, no versioning)
CDN_ISSUES=$(grep -rn 'unpkg\.com\|cdn\.jsdelivr\|esm\.sh\|cdnjs\.cloudflare' resources/views/ --include="*.edge" 2>/dev/null \
  | grep -v '@[0-9]\+\.[0-9]\+\|/[0-9]\+\.[0-9]\+' \
  | grep -v 'node_modules' || true)
if [ -z "$CDN_ISSUES" ]; then
  pass "All CDN URLs include a pinned version"
else
  COUNT=$(echo "$CDN_ISSUES" | wc -l | tr -d ' \r')
  fail "$COUNT CDN references without pinned version — add @x.y.z to each CDN URL"
  echo "$CDN_ISSUES" | head -5 | while IFS= read -r line; do echo "    $line"; done
fi
