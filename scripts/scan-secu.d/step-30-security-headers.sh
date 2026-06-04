#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 30. Shield headers (CSP + HSTS + X-Frame + X-Content-Type) ─────────────
# CSP / HSTS / X-Frame-Options / X-Content-Type-Options = defense-in-depth XSS
# amplification + clickjacking + MIME sniff. Config canonical : @adonisjs/shield
# dans config/shield.ts avec policy explicite (pas 'unsafe-inline' global).
step 30 "Security headers (Shield CSP/HSTS/X-Frame/MIME)" 2 "A05 Misconfig"
SHIELD_FILE="config/shield.ts"
if [ ! -f "$SHIELD_FILE" ]; then
  fail "config/shield.ts MISSING — @adonisjs/shield required for production headers"
else
  HEADER_GAPS=""
  # CSP : doit avoir directives explicites (pas juste enabled: true sans policy)
  CSP_PRESENT=$(grep -nE "csp:\s*\{" "$SHIELD_FILE" 2>/dev/null || true)
  if [ -z "$CSP_PRESENT" ]; then
    HEADER_GAPS="${HEADER_GAPS}    - CSP block missing in shield.ts"$'\n'
  else
    # 'unsafe-inline' acceptable uniquement avec annotation justifiée
    UNSAFE_INLINE=$(grep -nE "unsafe-inline" "$SHIELD_FILE" 2>/dev/null \
      | grep -v "canonical-skip:csp" || true)
    if [ -n "$UNSAFE_INLINE" ]; then
      HEADER_GAPS="${HEADER_GAPS}    - CSP 'unsafe-inline' present (annotate canonical-skip:csp:<reason> if intentional)"$'\n'
    fi
  fi
  # HSTS : enabled obligatoire en prod
  HSTS_PRESENT=$(grep -nE "hsts:\s*\{" "$SHIELD_FILE" 2>/dev/null || true)
  if [ -z "$HSTS_PRESENT" ]; then
    HEADER_GAPS="${HEADER_GAPS}    - HSTS block missing (transport-layer protection)"$'\n'
  fi
  # X-Frame-Options : protection clickjacking
  XFRAME_PRESENT=$(grep -nE "xFrame:\s*\{|x-frame" "$SHIELD_FILE" 2>/dev/null || true)
  if [ -z "$XFRAME_PRESENT" ]; then
    HEADER_GAPS="${HEADER_GAPS}    - X-Frame-Options block missing (clickjacking protection)"$'\n'
  fi
  # X-Content-Type-Options : MIME sniff protection (généralement 'noSniff: true')
  NOSNIFF_PRESENT=$(grep -nE "noSniff\s*:|contentTypeSniffing" "$SHIELD_FILE" 2>/dev/null || true)
  if [ -z "$NOSNIFF_PRESENT" ]; then
    HEADER_GAPS="${HEADER_GAPS}    - X-Content-Type-Options noSniff missing"$'\n'
  fi
  if [ -z "$HEADER_GAPS" ]; then
    pass "Shield headers configured (CSP + HSTS + X-Frame + noSniff)"
  else
    fail "Shield headers gaps:"
    printf '%s' "$HEADER_GAPS"
  fi
fi
