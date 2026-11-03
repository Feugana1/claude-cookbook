#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 8. SSRF scan (private IP in SMTP/fetch) ─────────────────────────────────
step 8 "SSRF scan (private network access)" 2 "A05 Misconfig"
SSRF_ISSUES=$(grep -rn 'localhost\|127\.0\.0\.1\|0\.0\.0\.0' app/services/ app/controllers/ --include="*.ts" 2>/dev/null \
  | grep -v 'test\|spec\|PRIVATE_IP_PATTERN\|eslint\|comment\|\/\/' || true)
if [ -z "$SSRF_ISSUES" ]; then
  pass "No hardcoded localhost/private IPs in services"
else
  COUNT=$(echo "$SSRF_ISSUES" | wc -l | tr -d ' \r')
  warn "$COUNT references to localhost/private IPs — review"
  echo "$SSRF_ISSUES" | head -3 | while IFS= read -r line; do echo "    $line"; done
fi
