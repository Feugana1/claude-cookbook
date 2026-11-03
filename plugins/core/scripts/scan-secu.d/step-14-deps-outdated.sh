#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 14. Dependency outdated ─────────────────────────────────────────────────
# Compte UNIQUEMENT les bumps MAJOR (semver major(current) < major(latest)). Les
# patches/minors sont des bumps safe et bruyent inutilement le scan — bumpés à
# l'occasion via npm install <pkg>@<latest>. Les majors nécessitent un sprint
# dédié (breaking changes, tests, migration code).
step 14 "Dependency outdated (major versions)" 3 "Supply chain"
OUTDATED=$(npm outdated --json 2>/dev/null || true)
if [ "$OUTDATED" = "{}" ] || [ -z "$OUTDATED" ]; then
  pass "All dependencies up to date"
else
  # jq filtre : garde les entries où major(current) < major(latest). Split sur "."
  # pour gérer 0.x.y vs x.y.z (semver pre-1.0 considère minor comme major).
  MAJOR_COUNT=$(echo "$OUTDATED" | jq -r '[to_entries[] | select(
    (.value.current | split(".") | .[0] | tonumber) <
    (.value.latest  | split(".") | .[0] | tonumber)
  )] | length' 2>/dev/null || echo "0")
  TOTAL_COUNT=$(echo "$OUTDATED" | jq -r 'length' 2>/dev/null || echo "?")
  if [ "${MAJOR_COUNT:-0}" -eq 0 ]; then
    pass "No major-version diff ($TOTAL_COUNT minor/patch outdated — bump à l'occasion)"
  else
    warn "$MAJOR_COUNT major outdated ($TOTAL_COUNT total) — run 'npm outdated' for details"
  fi
fi
