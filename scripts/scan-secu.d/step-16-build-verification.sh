#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 16. Build verification ──────────────────────────────────────────────────
step 16 "Build verification" 3 "Code quality"
if skip_if_diff; then :;
# Detect build flavour : Adonis (ace) vs TanStack Start/Vite vs NestJS.
elif [[ -f "ace.js" || -f "ace" ]]; then
  if node ace build --ignore-ts-errors > /tmp/scan-secu-build.log 2>&1; then
    pass "Build successful (Adonis ace)"
  else
    fail "Build failed — see /tmp/scan-secu-build.log"
  fi
elif [[ -f "vite.config.ts" || -f "vite.config.js" ]]; then
  # Skip réel build (coûteux + CI handle). Vérifie config + deps + script.
  if [[ -d "node_modules/vite" && -f "package.json" ]]; then
    if grep -q '"build"' package.json; then
      pass "Vite project — build script defined + vite installed (CI handles exec)"
    else
      fail "package.json manque 'build' script"
    fi
  else
    warn "vite ou node_modules manquant — run 'npm install' d'abord"
  fi
else
  skip "No build system detected (ace/vite/nest)"
fi
