#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 13. Prototype pollution scan ────────────────────────────────────────────
step 13 "Prototype pollution scan" 1 "A03 Injection"
PROTO_ISSUES=$(grep -rn '__proto__\|constructor\[' app/ --include="*.ts" 2>/dev/null \
  | grep -v 'proto-safe' || true)
MERGE_ISSUES=$(grep -rn 'Object\.assign\|\.\.\.req\.\|\.\.\.request\.' app/controllers/ app/services/ --include="*.ts" 2>/dev/null \
  | grep -v 'node_modules\|proto-safe' || true)
if [ -z "$PROTO_ISSUES" ] && [ -z "$MERGE_ISSUES" ]; then
  pass "No prototype pollution vectors"
else
  TOTAL_COUNT=0
  if [ -n "$PROTO_ISSUES" ]; then
    PC=$(echo "$PROTO_ISSUES" | wc -l | tr -d ' \r')
    TOTAL_COUNT=$((TOTAL_COUNT + PC))
  fi
  if [ -n "$MERGE_ISSUES" ]; then
    MC=$(echo "$MERGE_ISSUES" | wc -l | tr -d ' \r')
    TOTAL_COUNT=$((TOTAL_COUNT + MC))
  fi
  warn "$TOTAL_COUNT potential prototype pollution — review Object.assign/spread on request data"
  { echo "$PROTO_ISSUES"; echo "$MERGE_ISSUES"; } | head -5 | while IFS= read -r line; do
    [ -n "$line" ] && echo "    $line"
  done
fi
