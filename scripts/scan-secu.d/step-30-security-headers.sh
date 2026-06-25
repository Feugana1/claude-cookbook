#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 30. Security headers (CSP + HSTS + X-Frame + X-Content-Type) ───────────
# Defense-in-depth XSS amplification + clickjacking + MIME sniff.
# Multi-stack support :
#   - Adonis  : config/shield.ts via @adonisjs/shield
#   - NestJS  : main.ts via helmet middleware (chaque service ou gateway)
#   - Express : main.ts via helmet middleware
step 30 "Security headers (Shield CSP/HSTS/X-Frame/MIME)" 2 "A05 Misconfig"

# Stack detect
SHIELD_FILE="config/shield.ts"
HELMET_FILES=$(grep -rln "from ['\"]helmet['\"]\|require(['\"]helmet['\"])" \
  services/*/src/main.ts src/main.ts apps/*/src/main.ts 2>/dev/null || true)

if [ -f "$SHIELD_FILE" ]; then
  # ── Adonis path
  HEADER_GAPS=""
  CSP_PRESENT=$(grep -nE "csp:\s*\{" "$SHIELD_FILE" 2>/dev/null || true)
  if [ -z "$CSP_PRESENT" ]; then
    HEADER_GAPS="${HEADER_GAPS}    - CSP block missing in shield.ts"$'\n'
  else
    UNSAFE_INLINE=$(grep -nE "unsafe-inline" "$SHIELD_FILE" 2>/dev/null \
      | grep -v "canonical-skip:csp" || true)
    if [ -n "$UNSAFE_INLINE" ]; then
      HEADER_GAPS="${HEADER_GAPS}    - CSP 'unsafe-inline' present (annotate canonical-skip:csp:<reason> if intentional)"$'\n'
    fi
  fi
  HSTS_PRESENT=$(grep -nE "hsts:\s*\{" "$SHIELD_FILE" 2>/dev/null || true)
  [ -z "$HSTS_PRESENT" ] && HEADER_GAPS="${HEADER_GAPS}    - HSTS block missing (transport-layer protection)"$'\n'
  XFRAME_PRESENT=$(grep -nE "xFrame:\s*\{|x-frame" "$SHIELD_FILE" 2>/dev/null || true)
  [ -z "$XFRAME_PRESENT" ] && HEADER_GAPS="${HEADER_GAPS}    - X-Frame-Options block missing (clickjacking protection)"$'\n'
  NOSNIFF_PRESENT=$(grep -nE "noSniff\s*:|contentTypeSniffing" "$SHIELD_FILE" 2>/dev/null || true)
  [ -z "$NOSNIFF_PRESENT" ] && HEADER_GAPS="${HEADER_GAPS}    - X-Content-Type-Options noSniff missing"$'\n'
  if [ -z "$HEADER_GAPS" ]; then
    pass "Shield headers configured (CSP + HSTS + X-Frame + noSniff)"
  else
    fail "Shield headers gaps:"
    printf '%s' "$HEADER_GAPS"
  fi
elif [ -n "$HELMET_FILES" ]; then
  # ── NestJS / Express path : helmet middleware détecté
  GAPS=""
  # Au moins 1 fichier doit appeler helmet() en runtime
  HELMET_INVOKE=$(grep -nE "app\.use\(\s*helmet\(|helmet\(\s*\{" $HELMET_FILES 2>/dev/null || true)
  if [ -z "$HELMET_INVOKE" ]; then
    GAPS="${GAPS}    - helmet imported but not invoked via app.use(helmet(...))"$'\n'
  fi
  # HSTS : maxAge présent (helmet ON par défaut, mais explicite = mieux)
  HSTS_OK=$(grep -nE "hsts:\s*\{|maxAge" $HELMET_FILES 2>/dev/null || true)
  if [ -z "$HSTS_OK" ]; then
    GAPS="${GAPS}    - HSTS maxAge non explicite (vérifier helmet defaults)"$'\n'
  fi
  # X-Frame-Options : frameguard config (deny strict OU helmet default sameorigin)
  XFRAME_OK=$(grep -nE "frameguard|X-Frame-Options" $HELMET_FILES 2>/dev/null || true)
  if [ -z "$XFRAME_OK" ]; then
    GAPS="${GAPS}    - frameguard non explicite (helmet default sameorigin OK mais explicit recommandé)"$'\n'
  fi
  if [ -z "$GAPS" ]; then
    pass "helmet configured ($(echo "$HELMET_FILES" | wc -l | tr -d ' ') file(s)) — HSTS + frameguard explicites"
  else
    warn "helmet present but config gaps:"
    printf '%s' "$GAPS"
  fi
else
  fail "No security headers config found — expected config/shield.ts (Adonis) OR app.use(helmet()) (NestJS/Express)"
fi
