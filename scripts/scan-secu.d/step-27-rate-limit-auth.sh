#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 27. Rate limit on critical auth endpoints ──────────────────────────────
# Login / forgot_password / signup doivent avoir un throttle plus serré que
# le global IP throttle (300/min). Brute-force + credential stuffing.
step 27 "Rate limit on auth-critical endpoints" 2 "A07 Auth"
# Detection v2 : pattern PicStudio = controllers auth/*_controller.ts +
# dedicated throttles (authThrottle, signupThrottle, passwordResetThrottle)
# dans start/limiter.js + applied via .middleware() sur routes auth.
AUTH_CTRLS=$(ls app/controllers/auth/*.ts 2>/dev/null | head -5 || true)
DEDICATED_THROTTLES=$(grep -rnE "authThrottle|signupThrottle|passwordResetThrottle|loginThrottle" start/ 2>/dev/null | head -5 || true)
GLOBAL_THROTTLE_MW=$(ls app/middleware/global_throttle_middleware.ts 2>/dev/null || true)
if [ -z "$AUTH_CTRLS" ]; then
  skip "No auth controllers detected (app/controllers/auth/*.ts)"
else
  # 3 conditions de bonne santé : (a) auth controllers présents (b) throttles
  # dédiés définis (c) global throttle pour defense-in-depth
  if [ -n "$DEDICATED_THROTTLES" ] && [ -n "$GLOBAL_THROTTLE_MW" ]; then
    pass "Dedicated throttles (auth/signup/passwordReset) + global IP throttle (defense-in-depth)"
  elif [ -n "$GLOBAL_THROTTLE_MW" ]; then
    warn "Global throttle present but no dedicated auth throttles — verify login/signup/reset have stricter limits than 300/min/IP"
  else
    fail "Rate limit middleware MISSING — install @adonisjs/limiter + add throttles to auth routes"
  fi
fi
