#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 39. Sensitive fields serializeAs:null / @Exclude sur models ────────────
# Pattern pentest (T14 Sensitive data serialization) : les champs
# password/secret/apiKey/accessToken/refreshToken sur un model DOIVENT être
# exclus de la sérialisation JSON par défaut — sinon fuite via toJSON()/API.
#
# Multi-stack :
#   - Lucid (Adonis) : `@column({ serializeAs: null })` sur les 5-line window
#   - TypeORM/Prisma : `@Exclude()` de class-transformer
#   - Mongoose : `select: false` sur le schema field
#
# Whitelist : ajouter `canonical-skip:pending-<reason>` en commentaire proche
# pour les cas légitimes en cours de refactor (ex: vault-encrypt pending).
step 39 "Sensitive fields serializeAs:null / @Exclude sur models" 1 "A02 Crypto"

MODELS_DIR=""
[ -d app/models ] && MODELS_DIR="app/models"
[ -z "$MODELS_DIR" ] && [ -d src/entities ] && MODELS_DIR="src/entities"
[ -z "$MODELS_DIR" ] && [ -d src/models ] && MODELS_DIR="src/models"

if [ -z "$MODELS_DIR" ]; then
  skip "no app/models / src/entities / src/models dir — check manually"
  return 0 2>/dev/null || true
fi

LEAK_COLS=0
LEAK_SAMPLES=""
while IFS= read -r match; do
  [ -z "$match" ] && continue
  file="${match%%:*}"
  line_num="${match#*:}"
  line_num="${line_num%%:*}"
  ctx_start=$((line_num - 5))
  [ "$ctx_start" -lt 1 ] && ctx_start=1
  ctx=$(sed -n "${ctx_start},${line_num}p" "$file")
  if echo "$ctx" | grep -qE "serializeAs:\s*null|@Exclude\(|select:\s*false|canonical-skip:pending-"; then
    continue
  fi
  LEAK_COLS=$((LEAK_COLS + 1))
  LEAK_SAMPLES="${LEAK_SAMPLES}$file:$line_num"$'\n'
done < <(grep -rnE "declare (passwordHash|password|secret|apiKey|apiToken|accessToken|refreshToken|otpSecret|recoveryCode)[[:space:]]*:" "$MODELS_DIR" --include="*.ts" 2>/dev/null || true)

if [ "${LEAK_COLS:-0}" -eq 0 ]; then
  pass "Tous les champs password*/secret*/token* sur models ont serializeAs: null / @Exclude"
else
  fail "$LEAK_COLS champ(s) sensible(s) sans serializeAs:null — risque fuite toJSON()"
  printf '%s' "$LEAK_SAMPLES" | head -5 | while IFS= read -r sample; do echo "    $sample"; done
fi
