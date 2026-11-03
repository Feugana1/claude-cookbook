#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 25. Password reset token TTL ≤ 60 min ──────────────────────────────────
# Reset link landed in inbox = forwarded/screenshotted/leaked. TTL court limite
# la fenêtre d'attaque. Detect : controllers password-reset doivent expirer ≤1h.
step 25 "Password reset token TTL (≤ 60 min)" 2 "A07 Auth"
RESET_FILES=$(grep -rln "TOKEN_TYPES\.PASSWORD_RESET\|PASSWORD_RESET_TOKEN\|forgot_password" app/controllers/ app/services/ --include="*.ts" 2>/dev/null || true)
if [ -z "$RESET_FILES" ]; then
  skip "No password reset flow detected"
else
  RESET_TTL_BAD=""
  for f in $RESET_FILES; do
    # Extract expiresAt assignment context (perl multi-ligne)
    LONG_TTL=$(perl -0777 -ne '
      while (/expiresAt\s*=\s*DateTime[^\n]*?\.plus\(\s*\{\s*(hours?|days?|weeks?|months?)\s*:\s*(\d+)/g) {
        my ($unit, $n) = ($1, $2);
        my $minutes = $unit =~ /^h/ ? $n * 60 : ($unit =~ /^d/ ? $n * 1440 : 999999);
        if ($minutes > 60) {
          my $pos = $-[0];
          my $line = (substr($_, 0, $pos) =~ tr/\n//) + 1;
          print "$ARGV:$line:${n}${unit}\n";
        }
      }
    ' "$f" 2>/dev/null || true)
    if [ -n "$LONG_TTL" ]; then
      RESET_TTL_BAD="${RESET_TTL_BAD}${LONG_TTL}"$'\n'
    fi
  done
  RESET_TTL_BAD=$(printf '%s' "$RESET_TTL_BAD" | grep -v '^$' || true)
  if [ -z "$RESET_TTL_BAD" ]; then
    pass "Reset token TTL ≤ 60 min (verified in $(echo "$RESET_FILES" | wc -l | tr -d ' \r') file(s))"
  else
    fail "Reset token TTL > 60 min detected — shorten window"
    echo "$RESET_TTL_BAD" | head -3 | while IFS= read -r line; do echo "    $line"; done
  fi
fi
