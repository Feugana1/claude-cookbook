#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 9. Trivy filesystem scan ───────────────────────────────────────────────
step 9 "Trivy vulnerability scan" 2 "Supply chain"
if command -v trivy &>/dev/null; then
  TRIVY_DOCKER_CONFIG="${DOCKER_CONFIG:-/private/tmp/trivy-docker-config}"
  mkdir -p "$TRIVY_DOCKER_CONFIG" 2>/dev/null || true
  TRIVY_OUT=$(DOCKER_CONFIG="$TRIVY_DOCKER_CONFIG" TRIVY_DB_REPOSITORY="${TRIVY_DB_REPOSITORY:-ghcr.io/aquasecurity/trivy-db:2}" trivy fs --severity HIGH,CRITICAL --exit-code 0 --quiet . 2>&1 || true)
  if echo "$TRIVY_OUT" | grep -q "FATAL"; then
    warn "Trivy scan could not run — run 'trivy fs --severity HIGH,CRITICAL .' for details"
  elif echo "$TRIVY_OUT" | grep -q "Total: 0\|HIGH: 0, CRITICAL: 0"; then
    pass "No HIGH/CRITICAL vulnerabilities (Trivy)"
  elif echo "$TRIVY_OUT" | grep -q "Report Summary"; then
    if echo "$TRIVY_OUT" | grep -Eq '│[[:space:]]+[1-9][0-9]*[[:space:]]+│'; then
      TRIVY_COUNT=$(echo "$TRIVY_OUT" | grep -Ec '│[[:space:]]+[1-9][0-9]*[[:space:]]+│' || true)
      warn "$TRIVY_COUNT Trivy findings — run 'trivy fs --severity HIGH,CRITICAL .' for details"
    else
      pass "No HIGH/CRITICAL vulnerabilities (Trivy)"
    fi
  elif [ -z "$TRIVY_OUT" ]; then
    pass "No HIGH/CRITICAL vulnerabilities (Trivy)"
  else
    TRIVY_COUNT=$(echo "$TRIVY_OUT" | grep -c "HIGH\|CRITICAL" || echo "0")
    warn "$TRIVY_COUNT Trivy findings — run 'trivy fs --severity HIGH,CRITICAL .' for details"
  fi
else
  skip "Trivy not installed — Windows: 'winget install aquasecurity.trivy' | macOS: 'brew install trivy'"
fi
