#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 45. Quota check + create atomic (advisory lock ou unique constraint) ────
# Pattern pentest (T6 TOCTOU) : `count()` + `create()` sans lock/unique
# constraint permet à N requêtes simultanées de lire un compteur périmé et
# insérer au-delà du plafond (pentest : 15 req → 11 créés au lieu de 10).
#
# Solutions :
#   - PostgreSQL : `db.transaction()` + `pg_advisory_xact_lock(hashtext(userId))`
#   - MySQL : `SELECT ... FOR UPDATE` sur user row
#   - Contrainte DB unique OU partial unique index sur (userId, ressource)
#
# Ce step détecte le pattern positif (`pg_advisory_xact_lock` ou `forUpdate()`
# dans les services avec quota). Extension possible : audit anti-pattern
# count()+create() sans transaction.
step 45 "Quota check + create atomic (advisory lock ou FOR UPDATE)" 2 "A05 Misconfig"

QUOTA_SERVICES=$(grep -rln "MAX_.*_PER_TENANT\|MAX_.*_PER_USER\|quotaLimit\|quota.check" \
  app/services/ src/services/ --include="*.ts" 2>/dev/null | head -20 || true)

if [ -z "$QUOTA_SERVICES" ]; then
  skip "No quota services detected"
  return 0 2>/dev/null || true
fi

UNSAFE=0
UNSAFE_SAMPLES=""
for svc in $QUOTA_SERVICES; do
  # Chercher pattern count() suivi de create() dans le même fichier
  if grep -qE "\.count\(|count\('\*'" "$svc" 2>/dev/null && \
     grep -qE "\.create\(" "$svc" 2>/dev/null; then
    # Vérifier présence d'un lock/transaction/unique
    if grep -qE "pg_advisory_xact_lock|forUpdate\(\)|db\.transaction|\.transaction\(async" "$svc" 2>/dev/null; then
      continue  # protégé
    fi
    # Vérifier annotation canonical-skip
    if grep -q "canonical-skip:quota-toctou" "$svc" 2>/dev/null; then
      continue
    fi
    UNSAFE=$((UNSAFE + 1))
    UNSAFE_SAMPLES="${UNSAFE_SAMPLES}$svc"$'\n'
  fi
done

if [ "${UNSAFE:-0}" -eq 0 ]; then
  pass "Services quota utilisent lock atomic (advisory lock / FOR UPDATE / transaction)"
else
  warn "$UNSAFE service(s) quota avec count()+create() sans lock — race condition possible"
  printf '%s' "$UNSAFE_SAMPLES" | head -5 | while IFS= read -r sample; do echo "    $sample"; done
fi
