#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 23. i18n key symmetry (FR ↔ EN) ─────────────────────────────────────────
# Detecte les cles presentes dans FR mais absentes en EN (et inversement).
# Meme class de gap que le sweep OG : N surfaces, M < N respectent l'invariant.
step 23 "i18n key symmetry (FR vs EN)" 3 "Conventions"
SYMMETRY_REPORT=$(node -e "
const fs = require('fs')
const path = require('path')
function flatten(obj, prefix = '') {
  return Object.entries(obj).flatMap(([k, v]) =>
    v && typeof v === 'object' ? flatten(v, prefix ? prefix + '.' + k : k) : [prefix ? prefix + '.' + k : k]
  )
}
const frDir = path.join('resources', 'lang', 'fr')
const enDir = path.join('resources', 'lang', 'en')
const frFiles = fs.existsSync(frDir) ? fs.readdirSync(frDir).filter(f => f.endsWith('.json')) : []
let missingInEn = 0, missingInFr = 0, examples = []
for (const file of frFiles) {
  const frPath = path.join(frDir, file)
  const enPath = path.join(enDir, file)
  let frObj = {}, enObj = {}
  try { frObj = JSON.parse(fs.readFileSync(frPath, 'utf-8')) } catch {}
  try { enObj = JSON.parse(fs.readFileSync(enPath, 'utf-8')) } catch {}
  const frKeys = new Set(flatten(frObj))
  const enKeys = new Set(flatten(enObj))
  for (const k of frKeys) if (!enKeys.has(k)) { missingInEn++; if (examples.length < 5) examples.push(file + ' EN missing: ' + k) }
  for (const k of enKeys) if (!frKeys.has(k)) { missingInFr++; if (examples.length < 5) examples.push(file + ' FR missing: ' + k) }
}
console.log(missingInEn + ',' + missingInFr)
examples.forEach(e => console.error(e))
" 2>&1)
EX=$(echo "$SYMMETRY_REPORT" | grep -v '^[0-9]*,[0-9]*$' || true)
COUNTS=$(echo "$SYMMETRY_REPORT" | grep -E '^[0-9]+,[0-9]+$' | tail -1)
MISSING_EN=$(echo "$COUNTS" | cut -d, -f1)
MISSING_FR=$(echo "$COUNTS" | cut -d, -f2)
if [ "${MISSING_EN:-0}" = "0" ] && [ "${MISSING_FR:-0}" = "0" ]; then
  pass "FR and EN translation key sets are symmetric"
else
  TOTAL_MISSING=$((${MISSING_EN:-0} + ${MISSING_FR:-0}))
  warn "$TOTAL_MISSING translation key(s) asymmetric (EN missing: ${MISSING_EN:-0}, FR missing: ${MISSING_FR:-0})"
  echo "$EX" | head -5 | while IFS= read -r line; do echo "    $line"; done
fi
