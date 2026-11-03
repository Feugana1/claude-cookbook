#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 3. npm audit ────────────────────────────────────────────────────────────
step 3 "npm audit (dependency vulnerabilities)" 3 "Supply chain"
if ! skip_if_diff; then
  AUDIT_JSON=$(npm audit --omit=dev --json 2>/dev/null || true)
  AUDIT_BLOCKERS=$(AUDIT_JSON="$AUDIT_JSON" node -e "
const report = JSON.parse(process.env.AUDIT_JSON || '{}')
const metadata = report.metadata?.vulnerabilities || {}
const total = Number(metadata.high || 0) + Number(metadata.critical || 0)
process.stdout.write(String(total))
" 2>/dev/null || echo "1")
  if [ "$AUDIT_BLOCKERS" -eq 0 ]; then
    pass "No high/critical vulnerabilities"
  else
    fail "npm audit found $AUDIT_BLOCKERS high/critical vulnerabilities — run 'npm audit' for details"
  fi
fi
