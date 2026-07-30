#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 38. Sourcemaps supprimées post-upload Sentry ────────────────────────────
# Pattern pentest boîte noire (T13 Info disclosure) : les .map servies
# publiquement en prod permettent reconstruction du code frontend + endpoints
# internes. Fix : `sourcemaps.filesToDeleteAfterUpload` sur sentryVitePlugin.
#
# Multi-stack :
#   - Vite : vite.config.ts avec @sentry/vite-plugin
#   - Webpack : webpack.config.js avec @sentry/webpack-plugin
step 38 "Sourcemaps deleted after Sentry upload" 2 "A05 Misconfig"

VITE_CONFIG="vite.config.ts"
WEBPACK_CONFIG=$(find . -maxdepth 3 -name "webpack.config.js" -not -path "*/node_modules/*" 2>/dev/null | head -1)

if [ -f "$VITE_CONFIG" ]; then
  if grep -q "filesToDeleteAfterUpload" "$VITE_CONFIG" 2>/dev/null; then
    pass "vite.config filesToDeleteAfterUpload configuré"
  elif ! grep -q "sentryVitePlugin" "$VITE_CONFIG" 2>/dev/null; then
    skip "vite.config sans sentryVitePlugin — sourcemaps upload N/A"
  else
    fail "vite.config manque filesToDeleteAfterUpload — sourcemaps servies en prod"
  fi
elif [ -n "$WEBPACK_CONFIG" ]; then
  if grep -q "filesToDeleteAfterUpload\|deleteFilesAfterUpload" "$WEBPACK_CONFIG" 2>/dev/null; then
    pass "webpack.config sentry plugin deleteFilesAfterUpload configuré"
  elif ! grep -q "sentryWebpackPlugin\|SentryWebpackPlugin" "$WEBPACK_CONFIG" 2>/dev/null; then
    skip "webpack.config sans Sentry plugin — sourcemaps upload N/A"
  else
    fail "webpack.config Sentry plugin manque deleteFilesAfterUpload"
  fi
else
  skip "no vite.config.ts / webpack.config.js — check bundler config manually"
fi
