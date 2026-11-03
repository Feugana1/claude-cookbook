#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 42. session.regenerate() sur mutation credential (généraliste awk) ──────
# Pattern pentest T11 Auth lifecycle : toute méthode async controller qui
# mute credentials (password/2FA/recoveryCodes) DOIT appeler
# session.regenerate() dans la MÊME méthode — sinon cookie volé
# AVANT/APRÈS mutation reste utilisable.
#
# Signal sémantique généraliste (v0.3+ cookbook) : ne se limite plus au
# seul reset_password_controller. Awk parse le scope method-by-method,
# détecte mutation + vérifie invalidation same-method.
#
# Skip via commentaire `canonical-skip:session-regen <raison>` dans le
# body de la méthode (ex: mutation suivie d'un helper qui regenerate).
#
# Multi-stack :
#   - Adonis : `session.regenerate()` / `session.destroy()`
#   - NestJS : `req.session.regenerate()` / `req.session.destroy()`
#   - Express + express-session : idem
step 42 "session.regenerate() sur mutation credential sensible (générique)" 2 "A07 Auth"

CONTROLLERS_DIR=""
[ -d app/controllers ] && CONTROLLERS_DIR="app/controllers"
[ -d src/controllers ] && CONTROLLERS_DIR="src/controllers"

if [ -z "$CONTROLLERS_DIR" ]; then
  skip "no controllers/ dir — check manually"
  return 0 2>/dev/null || true
fi

CREDENTIAL_RE='user\.password[[:space:]]*=|\.passwordHash[[:space:]]*=|\.totpSecret[[:space:]]*=|\.isTwoFactorEnabled[[:space:]]*=|\.twoFactorRecoveryCodes[[:space:]]*=|\.recoveryCodes[[:space:]]*=|\.mfaSecret[[:space:]]*='
FILES_WITH_MUTATIONS=$(grep -rlE "$CREDENTIAL_RE" $CONTROLLERS_DIR --include="*.ts" 2>/dev/null || true)
MISS_COUNT=0
MISS_SAMPLES=""
for file in $FILES_WITH_MUTATIONS; do
  RESULT=$(awk -v re="$CREDENTIAL_RE" '
    /^  (async |private |public )?[a-zA-Z_][a-zA-Z0-9_]*\s*\(/ && !/=>/ {
      method_line=NR; method_name=$0; depth=0; has_mut=0; has_regen=0; has_skip=0; in_method=1
    }
    in_method {
      opens=gsub(/\{/, "{"); closes=gsub(/\}/, "}"); depth += opens - closes
      if ($0 ~ re) has_mut=1
      if ($0 ~ /session\.regenerate|session\.destroy|regenerateSession/) has_regen=1
      if ($0 ~ /canonical-skip:session-regen/) has_skip=1
      if (depth <= 0 && (opens > 0 || closes > 0) && NR > method_line) {
        if (has_mut && !has_regen && !has_skip) print method_line ":" method_name
        in_method=0
      }
    }
  ' "$file")
  if [ -n "$RESULT" ]; then
    while IFS= read -r hit; do
      [ -z "$hit" ] && continue
      MISS_COUNT=$((MISS_COUNT + 1))
      MISS_SAMPLES="${MISS_SAMPLES}$file:$hit"$'\n'
    done <<< "$RESULT"
  fi
done

if [ "${MISS_COUNT:-0}" -eq 0 ]; then
  pass "Toute méthode mutant credential appelle session.regenerate() (ou canonical-skip)"
else
  fail "$MISS_COUNT méthode(s) mutant credential sans session.regenerate() — cookie volé reste valide"
  printf '%s' "$MISS_SAMPLES" | head -5 | while IFS= read -r sample; do echo "    $sample"; done
fi
