#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 33. Raw SQL — bare db.rawQuery outside tenant-scoped seam ─────────────
# Toute bypass du seam multi-tenant cote ORM (ex: `Model.forTenant(uid)`)
# laisse les requetes raw sans (a) validation des colonnes contre les
# migrations (loyalty-class bug : `column "n.contact_id" does not exist`
# survenu en prod 2026-06-03), (b) assertion `*.user_id = ?` bound au uid.
#
# Cette etape pousse a router chaque `db.rawQuery` via un seam dedie
# (par convention : `app/services/tenant_raw.ts` exportant `tenantRaw` +
# `systemRaw`). Voir myproject commit history + le pattern documente dans
# `docs/anti-patterns.md` §"Raw SQL seam".
#
# Configuration:
#   - SEAM_FILE     : chemin du module seam (default: app/services/tenant_raw.ts)
#   - SEAM_HELPERS  : helpers internes du seam a aussi exclure (regex pipe)
#   - Skip annote : `// canonical-skip:tenant-raw:<reason>` au-dessus de la ligne
#
# Initialement WARN — ratchet WARN→FAIL une fois la migration des sites
# legacy terminee (cf docs/features/raw-sql-tenant-seam.md du projet hote).
step 33 "Raw SQL — bare db.rawQuery outside tenant seam" 3 "A01 Access Control"

SEAM_FILE="${SEAM_FILE:-app/services/tenant_raw.ts}"
SEAM_HELPERS="${SEAM_HELPERS:-app/services/_helpers/schema_cache\.ts}"

# Skip if app/ doesn't exist (cookbook self-scan, library projects, etc.)
if [ ! -d "app" ]; then
  pass "No app/ tree — raw SQL seam not applicable"
else
  RAW_SQL_BARE=$(grep -rnE "\bdb\.rawQuery\b" \
    app/ --include="*.ts" 2>/dev/null \
    | grep -vE "${SEAM_FILE}|${SEAM_HELPERS}" \
    | grep -vE "// canonical-skip:tenant-raw:" \
    | grep -vE "//.*db\.rawQuery|\* " \
    || true)
  RAW_SQL_COUNT=$(printf '%s' "$RAW_SQL_BARE" | grep -c ':' || true)
  if [ "$RAW_SQL_COUNT" -eq 0 ]; then
    pass "All db.rawQuery routed through tenant seam ($SEAM_FILE)"
  else
    warn "$RAW_SQL_COUNT bare db.rawQuery call site(s) outside the tenant seam"
    echo "$RAW_SQL_BARE" | head -5 | while IFS= read -r line; do echo "    $line"; done
    echo "    Fix : route via tenantRaw(uid, sql, params) or systemRaw(sql, params, { reason })"
    echo "    Seam expected at: $SEAM_FILE (override via SEAM_FILE=<path>)"
  fi
fi
