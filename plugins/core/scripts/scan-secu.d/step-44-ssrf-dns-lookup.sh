#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 44. SSRF validator utilise résolution DNS post-check ────────────────────
# Pattern pentest (T17 SSRF completeness) : les validators d'URL sortante
# (webhooks, imports, redirects) DOIVENT faire résolution DNS + vérifier
# ALL les IPs résolues contre les ranges privées, sinon `127.0.0.1.nip.io`
# passe (résout vers loopback mais le hostname ne match aucun pattern local).
#
# Ranges obligatoires : 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16,
# 127.0.0.0/8, 169.254.0.0/16, ::1, fc00::/7, fe80::/10.
step 44 "SSRF validator utilise résolution DNS post-check" 2 "A05 Misconfig"

# Détecte le fichier webhook_service.ts (ou URL validator)
WEBHOOK_SVC=""
for candidate in \
  "app/services/webhooks/webhook_service.ts" \
  "src/services/webhooks/webhook.service.ts" \
  "src/webhook/webhook.service.ts"; do
  [ -f "$candidate" ] && WEBHOOK_SVC="$candidate" && break
done

# Fallback : chercher n'importe quel fichier avec `isSafeWebhookUrl` ou `isPrivateOrLoopback`
# Guard : ne grep que sur dirs existants (sinon `grep -r absentdir/` exit 2 tue le script sous set -e)
if [ -z "$WEBHOOK_SVC" ]; then
  SEARCH_DIRS=""
  [ -d app ] && SEARCH_DIRS="$SEARCH_DIRS app"
  [ -d src ] && SEARCH_DIRS="$SEARCH_DIRS src"
  if [ -n "$SEARCH_DIRS" ]; then
    WEBHOOK_SVC=$(grep -rl "isSafeWebhookUrl\|isPrivateOrLoopback\|SSRF" $SEARCH_DIRS --include="*.ts" 2>/dev/null | head -1 || true)
  fi
fi

if [ -z "$WEBHOOK_SVC" ] || [ ! -f "$WEBHOOK_SVC" ]; then
  skip "No webhook / SSRF validator found (checked common paths)"
  return 0 2>/dev/null || true
fi

if grep -qE "dnsPromises\.lookup|dns\.promises\.lookup|resolveDns|dns\.resolve4" "$WEBHOOK_SVC" 2>/dev/null; then
  pass "SSRF validator utilise dns.lookup post-check (défense anti-bypass FQDN)"
else
  fail "SSRF validator manque résolution DNS — bypass 127.0.0.1.nip.io possible"
fi
