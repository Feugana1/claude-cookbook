#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 32. Lucid ORM — colonne préfixée table avec camelCase ─────────────────
# Lucid auto-convertit `.where('userId', ...)` → `user_id` MAIS PAS
# `.where('table.userId', ...)` (le préfixe `table.` casse la naming-strategy).
# Résultat : crash runtime `column "table.userId" does not exist` non détecté
# au build TS. Cf docs/anti-patterns.md §"Base de données & ORM".
step 32 "Lucid ORM — table prefix camelCase columns" 2 "A09 Logging+Quality"

if [ ! -d "app" ]; then
  pass "No app/ tree — Lucid prefix check not applicable"
else
  LUCID_PREFIX_BAD=$(grep -rnE "\.(where|orWhere|andWhere|whereIn|orderBy|select|groupBy|having)\(\s*['\"][a-z_]+\.[a-z]+[A-Z]" \
    app/ --include="*.ts" 2>/dev/null \
    | grep -vE "//.*|\* " \
    | head -20 || true)
  if [ -z "$LUCID_PREFIX_BAD" ]; then
    pass "No camelCase column referenced with table prefix in Lucid queries"
  else
    COUNT=$(echo "$LUCID_PREFIX_BAD" | wc -l | tr -d ' \r')
    fail "$COUNT Lucid query(ies) with 'table.camelCase' — naming-strategy ne convertit pas le préfixe → crash runtime"
    echo "$LUCID_PREFIX_BAD" | head -10 | while IFS= read -r line; do echo "    $line"; done
    echo "    Fix : utiliser snake_case explicite quand le préfixe table est présent."
    echo "    Ex : .where('shop_campaign_assignments.user_id', uid) — pas .where('shop_campaign_assignments.userId', uid)"
  fi
fi
