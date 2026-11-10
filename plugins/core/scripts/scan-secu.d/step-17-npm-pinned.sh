#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 17. Unpinned npm dependencies ───────────────────────────────────────────
step 17 "Unpinned npm dependencies (^ or ~ or 'latest')" 3 "Supply chain"
UNPINNED=$(node -e "
const pkg = JSON.parse(require('fs').readFileSync('package.json', 'utf8'));
const issues = [];
// Expo projects: 'expo install' writes '~' ranges aligned on the SDK (patch-only);
// package-lock.json pins the exact versions, so only '^', 'latest' and '*' are flagged.
const deps = Object.assign({}, pkg.dependencies, pkg.devDependencies);
const tildeOk = Boolean(deps.expo);
for (const section of ['dependencies', 'devDependencies', 'overrides']) {
  for (const [name, ver] of Object.entries(pkg[section] || {})) {
    if (typeof ver === 'string' && ((tildeOk ? /^\^/ : /^[\^~]/).test(ver) || ver === 'latest' || ver === '*')) {
      issues.push(section + ' / ' + name + ': ' + ver);
    }
  }
}
process.stdout.write(issues.join('\n'));
" 2>/dev/null || true)
if [ -z "$UNPINNED" ]; then
  pass "All npm versions are pinned (no ^, ~, or latest)"
else
  COUNT=$(echo "$UNPINNED" | wc -l | tr -d ' \r')
  fail "$COUNT unpinned npm dependencies — remove ^ and ~ to ensure reproducible builds"
  echo "$UNPINNED" | head -10 | while IFS= read -r line; do echo "    $line"; done
fi
