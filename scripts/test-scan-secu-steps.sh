#!/usr/bin/env bash
# Teste les steps grep de scan-secu.d/ sur des fixtures : un fichier vulnérable
# doit être détecté (FAIL ou WARN), un fichier sain doit passer.
# Usage : bash scripts/test-scan-secu-steps.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGINS="$ROOT/plugins"
OUT=""
step() { :; }
pass() { OUT="PASS"; }
fail() { OUT="FAIL"; }
warn() { OUT="WARN"; }
skip() { OUT="SKIP"; }

FAILED=0
# run_case <step-file> <expected> <chemin-fixture> <contenu> [<chemin> <contenu>]...
# Le step est cherché dans plugins/*/scripts/scan-secu.d/.
run_case() {
  local step_file="$1" expected="$2" d src rel content
  shift 2
  src=$(ls "$PLUGINS"/*/scripts/scan-secu.d/"$step_file" 2>/dev/null | head -1)
  if [ -z "$src" ]; then echo "  FAIL $step_file introuvable"; FAILED=$((FAILED + 1)); return; fi
  d=$(mktemp -d)
  while [ "$#" -ge 2 ]; do
    rel="$1"; content="$2"; shift 2
    mkdir -p "$d/$(dirname "$rel")"
    printf '%s\n' "$content" > "$d/$rel"
  done
  OUT=""
  # shellcheck disable=SC1090
  (cd "$d" && source "$src" >/dev/null 2>&1; echo "$OUT") > "$d/.out"
  local got; got=$(tail -1 "$d/.out")
  if [ "$got" = "$expected" ]; then
    echo "  ok   $step_file → $expected"
  else
    echo "  FAIL $step_file : attendu $expected, obtenu '${got:-rien}'"; FAILED=$((FAILED + 1))
  fi
  rm -rf "$d"
}

echo "scan-secu steps"
run_case step-04-crypto-scan.sh FAIL app/services/token.ts 'const t = Math.random().toString(36)'
run_case step-04-crypto-scan.sh PASS app/services/token.ts 'const t = randomBytes(16).toString("hex")'

run_case step-06-sql-injection-scan.sh FAIL app/services/q.ts 'db.rawQuery(`select * from users where id = ${id}`)'
run_case step-06-sql-injection-scan.sh PASS app/services/q.ts 'db.rawQuery("select * from users where id = ?", [id])'

run_case step-08-ssrf-scan.sh WARN app/services/http.ts 'const base = "http://127.0.0.1:9000"'
run_case step-08-ssrf-scan.sh PASS app/services/http.ts 'const base = env.get("API_URL")'
run_case step-08-ssrf-scan.sh PASS app/services/http.ts '// dev only: http://localhost:3000'

run_case step-12-redos-scan.sh WARN app/controllers/c.ts 'const re = new RegExp(request.input("q"))'
run_case step-12-redos-scan.sh PASS app/controllers/c.ts 'const re = new RegExp("^a+$")'

run_case step-13-prototype-pollution.sh WARN app/controllers/c.ts 'Object.assign(user, request.all())'
run_case step-13-prototype-pollution.sh PASS app/controllers/c.ts 'const x = pick(request.all(), ["name"])'

run_case step-25-password-reset-ttl.sh FAIL app/services/reset.ts \
  'const k = TOKEN_TYPES.PASSWORD_RESET; token.expiresAt = DateTime.now().plus({ hours: 24 })'
run_case step-25-password-reset-ttl.sh PASS app/services/reset.ts \
  'const k = TOKEN_TYPES.PASSWORD_RESET; token.expiresAt = DateTime.now().plus({ minutes: 30 })'

# ── core 29-46 ──
run_case step-29-db-fk-indexes.sh WARN database/migrations/1_a.ts \
  "t.integer('user_id'); t.foreign('user_id').references('users.id')"
run_case step-29-db-fk-indexes.sh PASS database/migrations/1_a.ts \
  "t.index(['user_id']); t.foreign('user_id').references('users.id')"

run_case step-31-webhook-signatures.sh FAIL app/controllers/stripe_webhook_controller.ts \
  'async handle() { await Invoice.create({}); } // webhook'
run_case step-31-webhook-signatures.sh PASS app/controllers/stripe_webhook_controller.ts \
  'async handle() { stripe.webhooks.constructEvent(b, s, k); await Invoice.create({}); } // webhook'

run_case step-38-sourcemaps-deleted.sh FAIL vite.config.ts 'plugins: [sentryVitePlugin({ org: "x" })]'
run_case step-38-sourcemaps-deleted.sh PASS vite.config.ts \
  'plugins: [sentryVitePlugin({ sourcemaps: { filesToDeleteAfterUpload: ["**/*.map"] } })]'

run_case step-39-sensitive-fields-serialization.sh FAIL app/models/user.ts \
  '@column()
declare password: string'
run_case step-39-sensitive-fields-serialization.sh PASS app/models/user.ts \
  '@column({ serializeAs: null })
declare password: string'

run_case step-40-presigned-url-ttl.sh FAIL app/controllers/c.ts "const u = await drive.getSignedUrl(key, { expiresIn: '24h' })"
run_case step-40-presigned-url-ttl.sh PASS app/controllers/c.ts "const u = await drive.getSignedUrl(key, { expiresIn: '1h' })"

run_case step-41-reset-tokens-invalidation.sh FAIL app/controllers/auth/forgot_password_controller.ts \
  'async handle() {
  await Token.create({ type: "PASSWORD_RESET" })
}'
run_case step-41-reset-tokens-invalidation.sh PASS app/controllers/auth/forgot_password_controller.ts \
  'async handle() {
  await Token.query().where("userId", 1).update({ isRevoked: true })
  await Token.create({ type: "PASSWORD_RESET" })
}'

run_case step-43-oauth-state-not-base64-json.sh FAIL app/controllers/oauth_controller.ts \
  "const state = Buffer.from(JSON.stringify({ userId })).toString('base64')"
run_case step-43-oauth-state-not-base64-json.sh PASS app/controllers/oauth_controller.ts \
  "const state = randomBytes(32).toString('hex')"

run_case step-44-ssrf-dns-lookup.sh FAIL app/services/webhooks/webhook_service.ts \
  'function isSafeWebhookUrl(u) { return !u.includes("localhost") }'
run_case step-44-ssrf-dns-lookup.sh PASS app/services/webhooks/webhook_service.ts \
  'async function isSafeWebhookUrl(u) { const r = await dnsPromises.lookup(u, { all: true }) }'

run_case step-45-quota-atomic-lock.sh WARN app/services/q.ts \
  'const MAX_X_PER_USER = 10; const n = await X.query().count("*"); await X.create({})'
run_case step-45-quota-atomic-lock.sh PASS app/services/q.ts \
  'const MAX_X_PER_USER = 10; await db.transaction(async () => { const n = await X.query().count("*"); await X.create({}) })'

run_case step-46-health-endpoint-minimal.sh FAIL app/controllers/health_checks_controller.ts \
  'export default class H { async handle({ response }) { const report = await h.run(); return response.ok(report) } }'
run_case step-46-health-endpoint-minimal.sh PASS app/controllers/health_checks_controller.ts \
  'export default class H { async handle({ response }) { return response.ok({ status: "ok" }) } }'

# ── pack adonisjs ──
run_case step-05-xss-scan.sh WARN resources/views/a.edge '{{{ userBio }}}'
run_case step-05-xss-scan.sh PASS resources/views/a.edge '{{{ sanitizeHtml(userBio) }}}'

run_case step-26-cors-origin-lock.sh FAIL config/cors.ts "export default { origin: '*' }"
run_case step-26-cors-origin-lock.sh PASS config/cors.ts "export default { origin: ['https://x.fr'] }"

run_case step-32-lucid-camelcase-prefix.sh FAIL app/services/q.ts "Q.query().where('shop_orders.userId', uid)"
run_case step-32-lucid-camelcase-prefix.sh PASS app/services/q.ts "Q.query().where('shop_orders.user_id', uid)"

run_case step-33-raw-sql-seam.sh WARN app/services/q.ts 'await db.rawQuery("select 1")'
run_case step-33-raw-sql-seam.sh PASS app/services/q.ts 'await tenantRaw(uid, "select 1", [])'

# ── pack expo ──
EXPO_PKG='{"dependencies":{"expo":"~52.0.0"}}'
run_case step-50-expo-token-storage.sh FAIL package.json "$EXPO_PKG" src/a.ts "await AsyncStorage.setItem('authToken', t)"
run_case step-50-expo-token-storage.sh PASS package.json "$EXPO_PKG" src/a.ts "await SecureStore.setItemAsync('authToken', t, { keychainAccessible: SecureStore.WHEN_UNLOCKED_THIS_DEVICE_ONLY })"
run_case step-50-expo-token-storage.sh SKIP package.json '{"dependencies":{}}'

run_case step-51-expo-public-secrets.sh FAIL package.json "$EXPO_PKG" .env 'EXPO_PUBLIC_API_SECRET=abc'
run_case step-51-expo-public-secrets.sh PASS package.json "$EXPO_PKG" .env 'EXPO_PUBLIC_API_URL=https://x.fr'

run_case step-52-expo-cleartext-ats.sh FAIL package.json "$EXPO_PKG" src/a.ts 'const API_URL = "http://api.example.com"'
run_case step-52-expo-cleartext-ats.sh PASS package.json "$EXPO_PKG" src/a.ts 'const API_URL = "https://api.example.com"'

run_case step-53-expo-sensitive-logs.sh FAIL package.json "$EXPO_PKG" src/a.ts 'console.log("t", token)'
run_case step-53-expo-sensitive-logs.sh PASS package.json "$EXPO_PKG" src/a.ts 'console.log("ready")'

run_case step-58-expo-android-allowbackup.sh PASS package.json "$EXPO_PKG" app.json '{"expo":{"android":{"allowBackup":false}}}'
run_case step-58-expo-android-allowbackup.sh WARN package.json "$EXPO_PKG" app.json '{"expo":{"android":{"allowBackup":true}}}'

if [ "$FAILED" -gt 0 ]; then echo "$FAILED cas en échec"; exit 1; fi
echo "tous les cas passent"
