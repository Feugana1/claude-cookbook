#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 46. /health minimaliste sans inventaire dépendances ─────────────────────
# Pattern pentest (T13 Info disclosure) : `GET /health` public NE DOIT PAS
# révéler l'inventaire complet des dépendances (Node version, pool DB, Redis
# mémoire, queue, hostname interne). Cartographie infra = coût x1000 pour
# attaquant. Rapport détaillé → endpoint interne auth.
step 46 "Health endpoint minimaliste (pas d'inventaire infra)" 2 "A05 Misconfig"

HEALTH_FILE=""
for candidate in \
  "app/controllers/health_checks_controller.ts" \
  "src/controllers/health.controller.ts" \
  "src/health/health.controller.ts"; do
  [ -f "$candidate" ] && HEALTH_FILE="$candidate" && break
done

if [ -z "$HEALTH_FILE" ]; then
  skip "No health controller found (checked common paths)"
  return 0 2>/dev/null || true
fi

# Détecte handler public (souvent nommé `handle`/`check`/`get`) qui renvoie
# le rapport complet vs body minimaliste
if awk '/async (handle|check|get)\(/,/^  \}/' "$HEALTH_FILE" 2>/dev/null | \
   grep -qE "response\.(ok|serviceUnavailable)\(report\)|return report"; then
  fail "Health controller renvoie le rapport complet — fuite inventaire dépendances"
elif grep -qE "status.*['\"]ok['\"]|status.*['\"]degraded['\"]|status.*['\"]healthy['\"]" "$HEALTH_FILE" 2>/dev/null; then
  pass "Health endpoint retourne body minimaliste {status}"
else
  warn "Pattern /health minimaliste non détecté — vérifier manuellement $HEALTH_FILE"
fi
