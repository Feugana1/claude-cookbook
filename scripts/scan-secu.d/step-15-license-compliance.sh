#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 15. License compliance ──────────────────────────────────────────────────
step 15 "License compliance" 3 "Supply chain"
if skip_if_diff; then :; elif npx --no-install license-checker --help > /dev/null 2>&1; then
  FORBIDDEN=$(npx --no-install license-checker --failOn "GPL-2.0;GPL-3.0;AGPL-1.0;AGPL-3.0;SSPL-1.0;EUPL-1.1;EUPL-1.2" --production 2>&1 || true)
  if echo "$FORBIDDEN" | grep -q "Found forbidden"; then
    fail "Copyleft/viral licenses detected — run 'npx license-checker --failOn GPL-3.0 --production'"
  else
    pass "No copyleft/viral licenses in production deps"
  fi
else
  # Fallback: node-based scan (faster than find -exec on Windows)
  COPYLEFT=$(node -e "
    const fs = require('fs');
    const path = require('path');
    const dirs = fs.readdirSync('node_modules').slice(0, 500);
    const hits = [];
    for (const d of dirs) {
      try {
        const pkg = JSON.parse(fs.readFileSync(path.join('node_modules', d, 'package.json'), 'utf8'));
        const lic = (pkg.license || '');
        if (/GPL|AGPL|SSPL/i.test(lic)) hits.push(d + ': ' + lic);
      } catch {}
    }
    process.stdout.write(hits.slice(0, 5).join('\n'));
  " 2>/dev/null || true)
  if [ -z "$COPYLEFT" ]; then
    pass "No copyleft licenses detected (basic scan)"
  else
    COUNT=$(echo "$COPYLEFT" | wc -l | tr -d ' \r')
    warn "$COUNT packages with copyleft licenses — install 'npx license-checker' for full scan"
    echo "$COPYLEFT" | while IFS= read -r line; do echo "    $line"; done
  fi
fi
