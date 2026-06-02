#!/usr/bin/env bash
# ============================================================================
# PicStudio — Pre-push Security & Quality Scan
# Run before every commit/push to ensure code is clean, secure, and buildable.
# Usage: npm run scan   (Git Bash on Windows / bash on macOS/Linux)
# Optional tools:
#   Windows: winget install aquasecurity.trivy  |  winget install gitleaks
#   macOS:   brew install trivy                  |  brew install gitleaks
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

# Per-tier counters (bash 3.2 compat — no associative arrays)
T1_PASS=0; T1_FAIL=0; T1_WARN=0  # BLOCKER (A01 Access / A02 Crypto / A03 Injection / A04 Insecure Design)
T2_PASS=0; T2_FAIL=0; T2_WARN=0  # IMPORTANT (A05 Misconfig / A07 Auth / A09 Logging)
T3_PASS=0; T3_FAIL=0; T3_WARN=0  # ADVISORY (Supply chain / Code quality / Conventions)

# Current step tier context (set by step(), read by pass/fail/warn)
TIER=3
GROUP="Quality"
CURRENT_STEP=""
TOP_RISKS=""  # newline-separated "T<n> · <group> — <message>" entries for summary

step() {
  TIER="${3:-3}"
  GROUP="${4:-Quality}"
  CURRENT_STEP="$2"
  echo -e "\n${BLUE}${BOLD}[$1/${TOTAL}]${NC} ${BOLD}$2${NC} ${YELLOW}[T${TIER} · ${GROUP}]${NC}"
}
pass() {
  echo -e "  ${GREEN}PASS${NC} $1"; PASS=$((PASS + 1))
  case "$TIER" in 1) T1_PASS=$((T1_PASS + 1));; 2) T2_PASS=$((T2_PASS + 1));; *) T3_PASS=$((T3_PASS + 1));; esac
}
fail() {
  echo -e "  ${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1))
  case "$TIER" in 1) T1_FAIL=$((T1_FAIL + 1));; 2) T2_FAIL=$((T2_FAIL + 1));; *) T3_FAIL=$((T3_FAIL + 1));; esac
  TOP_RISKS="${TOP_RISKS}T${TIER} · ${GROUP} — ${CURRENT_STEP}: $1"$'\n'
}
warn() {
  echo -e "  ${YELLOW}WARN${NC} $1"; WARN=$((WARN + 1))
  case "$TIER" in 1) T1_WARN=$((T1_WARN + 1));; 2) T2_WARN=$((T2_WARN + 1));; *) T3_WARN=$((T3_WARN + 1));; esac
  # Track tier 1/2 warnings as risks (tier 3 warnings are dette — not blocking insights)
  if [ "${TIER:-3}" -le 2 ]; then
    TOP_RISKS="${TOP_RISKS}T${TIER} · ${GROUP} ⚠ — ${CURRENT_STEP}: $1"$'\n'
  fi
}
skip() { echo -e "  ${YELLOW}SKIP${NC} $1"; }

# Banner: marque la transition entre tiers — affichage groupé pour le user.
tier_banner() {
  echo ""
  echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
  echo -e "  ${BOLD}TIER $1 — $2${NC}"
  echo -e "  ${YELLOW}$3${NC}"
  echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
}

TOTAL=31

echo -e "${BOLD}============================================${NC}"
echo -e "${BOLD}  PicStudio — Pre-push Security Scan${NC}"
echo -e "${BOLD}============================================${NC}"

# ── 1. ESLint + SonarJS ────────────────────────────────────────────────────
step 1 "ESLint + SonarJS" 3 "Code quality"
if npx eslint . --quiet 2>/dev/null; then
  pass "0 errors"
else
  fail "ESLint errors — run 'npm run lint:fix' to auto-fix"
fi

# ── 2. TypeScript type check ────────────────────────────────────────────────
step 2 "TypeScript type check" 3 "Code quality"
if npx tsc --noEmit 2>/dev/null; then
  pass "No type errors"
else
  fail "TypeScript errors — run 'npx tsc --noEmit' for details"
fi

# ── 3. npm audit ────────────────────────────────────────────────────────────
step 3 "npm audit (dependency vulnerabilities)" 3 "Supply chain"
AUDIT_JSON=$(npm audit --omit=dev --json 2>/dev/null || true)
AUDIT_BLOCKERS=$(AUDIT_JSON="$AUDIT_JSON" node -e "
const report = JSON.parse(process.env.AUDIT_JSON || '{}')
const metadata = report.metadata?.vulnerabilities || {}
const total = Number(metadata.high || 0) + Number(metadata.critical || 0)
process.stdout.write(String(total))
" 2>/dev/null || echo "1")
if [ "$AUDIT_BLOCKERS" -eq 0 ]; then
  pass "No high/critical vulnerabilities"
else
  fail "npm audit found $AUDIT_BLOCKERS high/critical vulnerabilities — run 'npm audit' for details"
fi

# ── 4. Crypto scan ─────────────────────────────────────────────────────────
step 4 "Crypto scan (weak randomness)" 1 "A02 Crypto"
CRYPTO_ISSUES=$(grep -rn "Math\.random" app/services/ app/controllers/ --include="*.ts" 2>/dev/null || true)
if [ -z "$CRYPTO_ISSUES" ]; then
  pass "No Math.random() in services/controllers"
else
  COUNT=$(echo "$CRYPTO_ISSUES" | wc -l | tr -d ' \r')
  fail "$COUNT uses of Math.random() — replace with crypto.randomInt()"
  echo "$CRYPTO_ISSUES" | head -5 | while IFS= read -r line; do echo "    $line"; done
fi

# ── 5. XSS scan ────────────────────────────────────────────────────────────
step 5 "XSS scan (unescaped output)" 1 "A03 Injection"
XSS_ISSUES=$(grep -rn '{{{ ' resources/views/ --include="*.edge" 2>/dev/null \
  | grep -v 'sanitizeHtml\|ensureHtml\|safeJson\|JSON.stringify\|\$slots\|await \$slots\|csrfField\|vite\|@stack\|toAttrs' \
  | grep -v 'node_modules' || true)
if [ -z "$XSS_ISSUES" ]; then
  pass "All {{{ }}} outputs are sanitized"
else
  COUNT=$(echo "$XSS_ISSUES" | wc -l | tr -d ' \r')
  warn "$COUNT potential XSS — review {{{ }}} without sanitizeHtml/ensureHtml"
  echo "$XSS_ISSUES" | head -5 | while IFS= read -r line; do echo "    $line"; done
fi

# ── 6. SQL injection scan ──────────────────────────────────────────────────
step 6 "SQL injection scan" 1 "A03 Injection"
SQL_ISSUES=$(grep -rn 'rawQuery\|whereRaw\|havingRaw' app/ --include="*.ts" 2>/dev/null \
  | grep '\${' || true)
if [ -z "$SQL_ISSUES" ]; then
  pass "No string interpolation in raw SQL"
else
  COUNT=$(echo "$SQL_ISSUES" | wc -l | tr -d ' \r')
  fail "$COUNT raw SQL with \${} — use ? parameterized bindings"
  echo "$SQL_ISSUES" | head -5 | while IFS= read -r line; do echo "    $line"; done
fi

# ── 7. Secrets scan ────────────────────────────────────────────────────────
step 7 "Secrets scan (hardcoded credentials)" 1 "A02 Crypto"
SECRETS=$(grep -rn 'password\s*=\s*["\x27][^"\x27]*["\x27]' app/ config/ start/ --include="*.ts" 2>/dev/null \
  | grep -vi 'eslint\|placeholder\|validator\|env\.\|hash\.\|schema\|type.*password\|name.*password\|autocomplete\|payload\|test\|spec\|factory\|seed\|let password\|const password' \
  || true)
if [ -z "$SECRETS" ]; then
  pass "No hardcoded credentials detected"
else
  COUNT=$(echo "$SECRETS" | wc -l | tr -d ' \r')
  warn "$COUNT potential hardcoded secrets — review manually"
  echo "$SECRETS" | head -5 | while IFS= read -r line; do echo "    $line"; done
fi

# ── 8. SSRF scan (private IP in SMTP/fetch) ─────────────────────────────────
step 8 "SSRF scan (private network access)" 2 "A05 Misconfig"
SSRF_ISSUES=$(grep -rn 'localhost\|127\.0\.0\.1\|0\.0\.0\.0' app/services/ app/controllers/ --include="*.ts" 2>/dev/null \
  | grep -v 'test\|spec\|PRIVATE_IP_PATTERN\|eslint\|comment\|\/\/' || true)
if [ -z "$SSRF_ISSUES" ]; then
  pass "No hardcoded localhost/private IPs in services"
else
  COUNT=$(echo "$SSRF_ISSUES" | wc -l | tr -d ' \r')
  warn "$COUNT references to localhost/private IPs — review"
  echo "$SSRF_ISSUES" | head -3 | while IFS= read -r line; do echo "    $line"; done
fi

# ── 9. Trivy filesystem scan ───────────────────────────────────────────────
step 9 "Trivy vulnerability scan" 2 "Supply chain"
if command -v trivy &>/dev/null; then
  TRIVY_DOCKER_CONFIG="${DOCKER_CONFIG:-/private/tmp/trivy-docker-config}"
  mkdir -p "$TRIVY_DOCKER_CONFIG" 2>/dev/null || true
  TRIVY_OUT=$(DOCKER_CONFIG="$TRIVY_DOCKER_CONFIG" TRIVY_DB_REPOSITORY="${TRIVY_DB_REPOSITORY:-ghcr.io/aquasecurity/trivy-db:2}" trivy fs --severity HIGH,CRITICAL --exit-code 0 --quiet . 2>&1 || true)
  if echo "$TRIVY_OUT" | grep -q "FATAL"; then
    warn "Trivy scan could not run — run 'trivy fs --severity HIGH,CRITICAL .' for details"
  elif echo "$TRIVY_OUT" | grep -q "Total: 0\|HIGH: 0, CRITICAL: 0"; then
    pass "No HIGH/CRITICAL vulnerabilities (Trivy)"
  elif echo "$TRIVY_OUT" | grep -q "Report Summary"; then
    if echo "$TRIVY_OUT" | grep -Eq '│[[:space:]]+[1-9][0-9]*[[:space:]]+│'; then
      TRIVY_COUNT=$(echo "$TRIVY_OUT" | grep -Ec '│[[:space:]]+[1-9][0-9]*[[:space:]]+│' || true)
      warn "$TRIVY_COUNT Trivy findings — run 'trivy fs --severity HIGH,CRITICAL .' for details"
    else
      pass "No HIGH/CRITICAL vulnerabilities (Trivy)"
    fi
  elif [ -z "$TRIVY_OUT" ]; then
    pass "No HIGH/CRITICAL vulnerabilities (Trivy)"
  else
    TRIVY_COUNT=$(echo "$TRIVY_OUT" | grep -c "HIGH\|CRITICAL" || echo "0")
    warn "$TRIVY_COUNT Trivy findings — run 'trivy fs --severity HIGH,CRITICAL .' for details"
  fi
else
  skip "Trivy not installed — Windows: 'winget install aquasecurity.trivy' | macOS: 'brew install trivy'"
fi

# ── 10. Gitleaks (secrets in git history + files) ───────────────────────────
step 10 "Gitleaks (secrets detection)" 1 "A02 Crypto"
if command -v gitleaks &>/dev/null; then
  LEAKS_OUT=$(gitleaks detect --no-git --exit-code 0 --quiet 2>&1 || true)
  if echo "$LEAKS_OUT" | grep -q "leaks found: 0"; then
    pass "No secrets leaked"
  elif echo "$LEAKS_OUT" | grep -q "leaks found"; then
    fail "Secrets detected — run 'gitleaks detect --no-git -v' for details"
  else
    pass "No secrets leaked"
  fi
else
  skip "Gitleaks not installed — Windows: 'winget install gitleaks' | macOS: 'brew install gitleaks'"
fi

# ── 11. Code duplication (jscpd) ────────────────────────────────────────────
step 11 "Code duplication scan" 3 "Code quality"
if npx jscpd --version > /dev/null 2>&1; then
  DUP_OUT=$(npx jscpd app/ --min-lines 15 --min-tokens 80 --threshold 10 --silent 2>&1 || true)
  if echo "$DUP_OUT" | grep -q "Interrupted"; then
    fail "Code duplication > 10% — run 'npx jscpd app/ --min-lines 15' for details"
  else
    DUP_PCT=$(echo "$DUP_OUT" | grep -o '[0-9.]*%' | tail -1 || echo "0%")
    if [ -z "$DUP_PCT" ]; then DUP_PCT="0%"; fi
    pass "Duplication: $DUP_PCT (threshold: 10%)"
  fi
else
  skip "jscpd not installed — run 'npm install -D jscpd' to enable"
fi

# ── 12. ReDoS scan (catastrophic backtracking regex) ────────────────────────
step 12 "ReDoS scan (regex denial of service)" 1 "A03 Injection"
REDOS_ISSUES=$(grep -rn 'new RegExp\|\.match(\|\.replace(\|\.split(' app/controllers/ app/services/ app/validators/ --include="*.ts" 2>/dev/null \
  | grep -v 'node_modules\|\.spec\.\|\.test\.' || true)
# Lines annotated with "audited" OR "redos-safe" are treated as reviewed and skipped.
REDOS_DANGEROUS=$(echo "$REDOS_ISSUES" | grep -i 'request\.\|input\.\|params\.\|body\.\|query\.' \
  | grep -v 'audited\|redos-safe' || true)
if [ -z "$REDOS_DANGEROUS" ]; then
  pass "No user-input regex patterns detected"
else
  COUNT=$(echo "$REDOS_DANGEROUS" | wc -l | tr -d ' \r')
  warn "$COUNT regex on user input — verify no catastrophic backtracking"
  echo "$REDOS_DANGEROUS" | head -5 | while IFS= read -r line; do echo "    $line"; done
fi

# ── 13. Prototype pollution scan ────────────────────────────────────────────
step 13 "Prototype pollution scan" 1 "A03 Injection"
PROTO_ISSUES=$(grep -rn '__proto__\|constructor\[' app/ --include="*.ts" 2>/dev/null \
  | grep -v 'proto-safe' || true)
MERGE_ISSUES=$(grep -rn 'Object\.assign\|\.\.\.req\.\|\.\.\.request\.' app/controllers/ app/services/ --include="*.ts" 2>/dev/null \
  | grep -v 'node_modules\|proto-safe' || true)
if [ -z "$PROTO_ISSUES" ] && [ -z "$MERGE_ISSUES" ]; then
  pass "No prototype pollution vectors"
else
  TOTAL_COUNT=0
  if [ -n "$PROTO_ISSUES" ]; then
    PC=$(echo "$PROTO_ISSUES" | wc -l | tr -d ' \r')
    TOTAL_COUNT=$((TOTAL_COUNT + PC))
  fi
  if [ -n "$MERGE_ISSUES" ]; then
    MC=$(echo "$MERGE_ISSUES" | wc -l | tr -d ' \r')
    TOTAL_COUNT=$((TOTAL_COUNT + MC))
  fi
  warn "$TOTAL_COUNT potential prototype pollution — review Object.assign/spread on request data"
  { echo "$PROTO_ISSUES"; echo "$MERGE_ISSUES"; } | head -5 | while IFS= read -r line; do
    [ -n "$line" ] && echo "    $line"
  done
fi

# ── 14. Dependency outdated ─────────────────────────────────────────────────
# Compte UNIQUEMENT les bumps MAJOR (semver major(current) < major(latest)). Les
# patches/minors sont des bumps safe et bruyent inutilement le scan — bumpés à
# l'occasion via npm install <pkg>@<latest>. Les majors nécessitent un sprint
# dédié (breaking changes, tests, migration code).
step 14 "Dependency outdated (major versions)" 3 "Supply chain"
OUTDATED=$(npm outdated --json 2>/dev/null || true)
if [ "$OUTDATED" = "{}" ] || [ -z "$OUTDATED" ]; then
  pass "All dependencies up to date"
else
  # jq filtre : garde les entries où major(current) < major(latest). Split sur "."
  # pour gérer 0.x.y vs x.y.z (semver pre-1.0 considère minor comme major).
  MAJOR_COUNT=$(echo "$OUTDATED" | jq -r '[to_entries[] | select(
    (.value.current | split(".") | .[0] | tonumber) <
    (.value.latest  | split(".") | .[0] | tonumber)
  )] | length' 2>/dev/null || echo "0")
  TOTAL_COUNT=$(echo "$OUTDATED" | jq -r 'length' 2>/dev/null || echo "?")
  if [ "${MAJOR_COUNT:-0}" -eq 0 ]; then
    pass "No major-version diff ($TOTAL_COUNT minor/patch outdated — bump à l'occasion)"
  else
    warn "$MAJOR_COUNT major outdated ($TOTAL_COUNT total) — run 'npm outdated' for details"
  fi
fi

# ── 15. License compliance ──────────────────────────────────────────────────
step 15 "License compliance" 3 "Supply chain"
if npx --no-install license-checker --help > /dev/null 2>&1; then
  FORBIDDEN=$(npx --no-install license-checker --failOn "GPL-2.0;GPL-3.0;AGPL-1.0;AGPL-3.0;SSPL-1.0;EUPL-1.1;EUPL-1.2" --production 2>&1 || true)
  if echo "$FORBIDDEN" | grep -q "Found forbidden"; then
    fail "Copyleft/viral licenses detected — run 'npx license-checker --failOn GPL-3.0 --production'"
  else
    pass "No copyleft/viral licenses in production deps"
  fi
else
  # Fallback: node-based scan (faster than find -exec on Windows)
  COPYLEFT=$(node -e "
    const fs = require('fs');
    const path = require('path');
    const dirs = fs.readdirSync('node_modules').slice(0, 500);
    const hits = [];
    for (const d of dirs) {
      try {
        const pkg = JSON.parse(fs.readFileSync(path.join('node_modules', d, 'package.json'), 'utf8'));
        const lic = (pkg.license || '');
        if (/GPL|AGPL|SSPL/i.test(lic)) hits.push(d + ': ' + lic);
      } catch {}
    }
    process.stdout.write(hits.slice(0, 5).join('\n'));
  " 2>/dev/null || true)
  if [ -z "$COPYLEFT" ]; then
    pass "No copyleft licenses detected (basic scan)"
  else
    COUNT=$(echo "$COPYLEFT" | wc -l | tr -d ' \r')
    warn "$COUNT packages with copyleft licenses — install 'npx license-checker' for full scan"
    echo "$COPYLEFT" | while IFS= read -r line; do echo "    $line"; done
  fi
fi

# ── 16. Build verification ──────────────────────────────────────────────────
step 16 "Build verification" 3 "Code quality"
if node ace build --ignore-ts-errors > /dev/null 2>&1; then
  pass "Build successful"
else
  fail "Build failed — run 'node ace build --ignore-ts-errors' for details"
fi

# ── 17. Unpinned npm dependencies ───────────────────────────────────────────
step 17 "Unpinned npm dependencies (^ or ~ or 'latest')" 3 "Supply chain"
UNPINNED=$(node -e "
const pkg = JSON.parse(require('fs').readFileSync('package.json', 'utf8'));
const issues = [];
for (const section of ['dependencies', 'devDependencies', 'overrides']) {
  for (const [name, ver] of Object.entries(pkg[section] || {})) {
    if (typeof ver === 'string' && (/^[\^~]/.test(ver) || ver === 'latest' || ver === '*')) {
      issues.push(section + ' / ' + name + ': ' + ver);
    }
  }
}
process.stdout.write(issues.join('\n'));
" 2>/dev/null || true)
if [ -z "$UNPINNED" ]; then
  pass "All npm versions are pinned (no ^, ~, or latest)"
else
  COUNT=$(echo "$UNPINNED" | wc -l | tr -d ' \r')
  fail "$COUNT unpinned npm dependencies — remove ^ and ~ to ensure reproducible builds"
  echo "$UNPINNED" | head -10 | while IFS= read -r line; do echo "    $line"; done
fi

# ── 18. CDN versions in Edge templates ──────────────────────────────────────
step 18 "Unpinned CDN script/link URLs in Edge templates" 3 "Supply chain"
# Only check versioned script/style CDN hosts (exclude flagcdn.com: dynamic flag image urls, no versioning)
CDN_ISSUES=$(grep -rn 'unpkg\.com\|cdn\.jsdelivr\|esm\.sh\|cdnjs\.cloudflare' resources/views/ --include="*.edge" 2>/dev/null \
  | grep -v '@[0-9]\+\.[0-9]\+\|/[0-9]\+\.[0-9]\+' \
  | grep -v 'node_modules' || true)
if [ -z "$CDN_ISSUES" ]; then
  pass "All CDN URLs include a pinned version"
else
  COUNT=$(echo "$CDN_ISSUES" | wc -l | tr -d ' \r')
  fail "$COUNT CDN references without pinned version — add @x.y.z to each CDN URL"
  echo "$CDN_ISSUES" | head -5 | while IFS= read -r line; do echo "    $line"; done
fi

# ── 19. File size ratchet (CLAUDE.md §14) ───────────────────────────────────
step 19 "File size ratchet (controllers 300 / services 400 / templates 800)" 3 "Code quality"
# NB : capturer le code retour réel — `$(cmd || true)` puis `$?` renvoie
# toujours 0 (exit du `true`), ce qui rendait cette étape toujours verte.
if RATCHET_OUT=$(node scripts/check-file-sizes.js 2>&1); then
  # Extract the shrunk lines from the output for the info-level feedback
  SHRUNK_LINE=$(echo "$RATCHET_OUT" | grep "baseline file(s) shrunk" || true)
  if [ -n "$SHRUNK_LINE" ]; then
    pass "All files within budget — $(echo "$SHRUNK_LINE" | sed 's/^[[:space:]]*✓ //')"
  else
    pass "All files within budget (see scripts/file-size-baseline.json)"
  fi
else
  fail "File size regression — run 'node scripts/check-file-sizes.js' for details"
  echo "$RATCHET_OUT" | grep -E '^\s+\S.*lines|^\s+\S.*→' | head -10 | while IFS= read -r line; do
    echo "    $line"
  done
fi

# ── 20. Discipline files integrity (CLAUDE.md §17) ──────────────────────────
step 20 "Discipline files integrity (lessons.md + dev-changelog.md + §17)" 3 "Conventions"
DISC_FAIL=0
if [ ! -f docs/lessons.md ]; then
  fail "docs/lessons.md missing — Karpathy 4 + leçons projet doivent rester versionnées"
  DISC_FAIL=1
elif ! grep -q "Karpathy 4" docs/lessons.md; then
  fail "docs/lessons.md exists but missing 'Karpathy 4' section — vérifier contenu §1"
  DISC_FAIL=1
fi
if [ ! -f docs/dev-changelog.md ]; then
  warn "docs/dev-changelog.md missing — release notes internes doivent y être consignées (pas dans CLAUDE.md)"
fi
if ! grep -q "## 17. Workflow Agentic" CLAUDE.md; then
  fail "CLAUDE.md §17 'Workflow Agentic' missing — règles process supprimées par erreur ?"
  DISC_FAIL=1
fi
if ! grep -q "docs/lessons.md" CLAUDE.md; then
  fail "CLAUDE.md ne référence plus docs/lessons.md — boucle d'auto-amélioration cassée"
  DISC_FAIL=1
fi
# Warn si le commit ajoute ≥3 nouveaux controllers sans toucher docs/features/
if git rev-parse HEAD >/dev/null 2>&1; then
  NEW_CTRL=$(git diff --cached --name-only --diff-filter=A 2>/dev/null | grep -c '^app/controllers/.*\.ts$' || true)
  TOUCHED_PLANS=$(git diff --cached --name-only 2>/dev/null | grep -c '^docs/features/' || true)
  if [ "${NEW_CTRL:-0}" -ge 3 ] && [ "${TOUCHED_PLANS:-0}" -eq 0 ]; then
    warn "$NEW_CTRL nouveaux controllers staged sans plan dans docs/features/ — voir docs/feature-plan-template.md"
  fi
fi
if [ $DISC_FAIL -eq 0 ]; then
  pass "Discipline files OK (lessons.md + §17 référencent docs/lessons.md)"
fi

# ── 21. Project anti-patterns (CLAUDE.md §13 / docs/anti-patterns.md) ───────
step 21 "Project anti-patterns (Edge / Alpine)" 3 "Conventions"
# P0 — `||` dans @each : le mini-parseur @each tokenise `|` comme pipe → crash.
ANTI_EACH=$(grep -rn '@each(' resources/views/ --include="*.edge" 2>/dev/null | grep '||' || true)
# P1 — `{{{ }}}` dans x-data : utiliser <script type="application/json">.
ANTI_XDATA=$(grep -rn 'x-data=' resources/views/ --include="*.edge" 2>/dev/null | grep '{{{' || true)
ANTI_HITS=$(printf '%s\n%s\n' "$ANTI_EACH" "$ANTI_XDATA" | grep -E ':[0-9]+:' || true)
if [ -z "$ANTI_HITS" ]; then
  pass "No '||' in @each, no {{{ }}} in x-data"
else
  COUNT=$(echo "$ANTI_HITS" | wc -l | tr -d ' \r')
  fail "$COUNT Edge anti-pattern(s) — see docs/anti-patterns.md (Edge.js / Alpine.js)"
  echo "$ANTI_HITS" | head -5 | while IFS= read -r line; do echo "    $line"; done
fi
# WARN — anti-patterns pré-existants à migrer (n'échouent pas le scan).
STIMULUS=$(grep -rln 'data-controller="confirm"' resources/views/ --include="*.edge" 2>/dev/null || true)
if [ -n "$STIMULUS" ]; then
  SC=$(echo "$STIMULUS" | wc -l | tr -d ' \r')
  warn "$SC file(s) using data-controller=\"confirm\" — Stimulus non câblé, migrer vers Alpine 2-step"
fi

# ── 22. Feature duplication & convention divergence ────────────────────────
# Detecte les "N facons differentes de faire la meme chose" : pour chaque
# convention canonique du projet, grep les alternatives interdites. Source de
# verite = CLAUDE.md §13 + docs/anti-patterns.md.
#
# Ajout d'une nouvelle convention :
#   1. Definir le canonical (ex: `buildPublicShareMeta`)
#   2. Lister les forbidden patterns (ex: ad-hoc OG building)
#   3. Ajouter un sous-check ci-dessous (CHECK_<NAME>) + ligne de DETAILS
#
# Pour opter out localement : commentaire `// canonical-skip:<rule>:<reason>`
# au-dessus du code concerne (ex: `// canonical-skip:storage:integration test`).
step 22 "Feature duplication & convention divergence (IDOR + SoftDelete + Conv)" 1 "A01 Access Control"

CONV_HITS=0
CONV_DETAILS=""

# ── A. OG meta : canonical = buildPublicShareMeta sur surfaces publiques ────
# Forbidden : public controller render sans buildPublicShareMeta + sans annotation.
# Opt-out : `// canonical-skip:og:<reason>` dans le fichier (ex: anonymous cart).
OG_GAPS=""
for f in $(grep -rln "view.render" app/controllers/public_*.ts app/controllers/portal_reviews_controller.ts 2>/dev/null \
  | grep -v "_helpers\|_show_view\|_show_state" || true); do
  if grep -qE "canonical-skip:og:" "$f"; then continue; fi
  if ! grep -qE "buildPublicShareMeta|ogImage|og_image|ogImageUrl" "$f"; then
    OG_GAPS="${OG_GAPS}${f}"$'\n'
  fi
done
OG_GAPS=$(printf '%s' "$OG_GAPS" | grep -v '^$' || true)
if [ -n "$OG_GAPS" ]; then
  C=$(echo "$OG_GAPS" | wc -l | tr -d ' \r')
  CONV_HITS=$((CONV_HITS + C))
  CONV_DETAILS="${CONV_DETAILS}  [OG] $C public ctrl(s) sans buildPublicShareMeta (annotate '// og-skip-reason')"$'\n'
  echo "$OG_GAPS" | head -3 | while IFS= read -r line; do CONV_DETAILS="${CONV_DETAILS}      - $line"$'\n'; printf '      - %s\n' "$line" > /dev/null; done > /dev/null
fi

# ── B. Storage : canonical = StorageService — interdit `drive.use(` direct ──
DRIVE_DIRECT=$(grep -rn "drive\.use(" app/controllers/ app/services/ --include="*.ts" 2>/dev/null \
  | grep -v "storage_service\.ts\|//.*canonical-skip:storage" || true)
if [ -n "$DRIVE_DIRECT" ]; then
  C=$(echo "$DRIVE_DIRECT" | wc -l | tr -d ' \r')
  CONV_HITS=$((CONV_HITS + C))
  CONV_DETAILS="${CONV_DETAILS}  [Storage] $C direct drive.use() (canonical: StorageService.upload/delete/getStream)"$'\n'
  echo "$DRIVE_DIRECT" | head -3 | while IFS= read -r line; do printf '      - %s\n' "$line" > /dev/null; done > /dev/null
fi

# ── C. Auth scope : canonical = effectiveUserId — interdit `auth.user.id` direct ──
AUTH_RAW=$(grep -rnE "\.where\(['\"]userId['\"], auth\.user\?\.id" app/controllers/ app/services/ --include="*.ts" 2>/dev/null \
  | grep -v "//.*canonical-skip:auth" || true)
AUTH_RAW2=$(grep -rnE "\.where\(['\"]user_id['\"], auth\.user\?\.id" app/controllers/ app/services/ --include="*.ts" 2>/dev/null \
  | grep -v "//.*canonical-skip:auth" || true)
AUTH_TOTAL=$(printf '%s\n%s\n' "$AUTH_RAW" "$AUTH_RAW2" | grep -E ':[0-9]+:' || true)
if [ -n "$AUTH_TOTAL" ]; then
  C=$(echo "$AUTH_TOTAL" | wc -l | tr -d ' \r')
  CONV_HITS=$((CONV_HITS + C))
  CONV_DETAILS="${CONV_DETAILS}  [Auth] $C .where('userId', auth.user.id) — canonical: effectiveUserId (middleware team)"$'\n'
fi

# ── C-bis. IDOR : .findOrFail / .firstOrFail sans .where('userId') adjacent ──
# Anti-pattern OWASP A01:2021 — un controller fetch un Model by ID sans verifier
# ownership. Detection multi-ligne perl : si Document/Gallery/Service/Contact/Booking
# .query() ... .firstOrFail() ne contient PAS .where('userId') dans la chaine,
# c'est un IDOR potentiel.
# v2 strict : match UNIQUEMENT .firstOrFail/.findOrFail (chemin critique throw)
# pas .first() qui retourne null safely. Exclus public/portal/admin/og/transfer-download
# qui auth par token, pas par userId.
IDOR_RAW=$(perl -0777 -ne '
  while (/(?<![A-Za-z])(Document|Gallery|Service|Contact|Booking|Transfer|Invoice|Quote)\.(?:query|findOrFail|findByOrFail)\(\)([^;]{0,800}?)(?:\.firstOrFail\(|\.findOrFail\()/sg) {
    my ($model, $block) = ($1, $2);
    next if $block =~ /(?:where|whereHas|whereExists)\s*\(\s*["\x27]userId["\x27]\s*,/;
    next if $block =~ /(?:where|whereHas|whereExists)\s*\(\s*["\x27]user_id["\x27]\s*,/;
    next if $block =~ /canonical-skip:idor/;
    my $pos = $-[0];
    my $line = (substr($_, 0, $pos) =~ tr/\n//) + 1;
    print "$ARGV:$line:$model\n";
  }
' app/controllers/*.ts app/controllers/**/*.ts 2>/dev/null \
  | grep -vE "/(public_|portal_|admin/|og_image_|transfer_download_)" || true)
if [ -n "$IDOR_RAW" ]; then
  C=$(echo "$IDOR_RAW" | wc -l | tr -d ' \r')
  CONV_HITS=$((CONV_HITS + C))
  CONV_DETAILS="${CONV_DETAILS}  [IDOR] $C Model.query().firstOrFail() sans .where('userId') (annotate '// canonical-skip:idor:<reason>' si public/admin/token-auth)"$'\n'
fi

# ── D. Document soft-delete : canonical = .whereNull('deletedAt') ──────────
# Detection multi-ligne : un Document.query() suivi d'une chaine .where...().first()/etc
# doit contenir whereNull('deletedAt') dans la chaine. Perl slurp mode car bash grep
# est mono-ligne et donne des faux positifs.
DOC_NO_SOFT=$(perl -0777 -ne '
  while (/(?<![A-Za-z])Document\.query\(\)([^;]*?)(?:\.first\(|\.firstOrFail\(|\.exec\(|\.paginate\(|\.count\(|\.update\(|\.delete\(|\.forUpdate\()/sg) {
    my $block = $1;
    next if $block =~ /whereNull\(["\x27]deletedAt["\x27]\)/;
    next if $block =~ /canonical-skip:soft-delete/;
    my $pos = $-[0];
    my $line = (substr($_, 0, $pos) =~ tr/\n//) + 1;
    print "$ARGV:$line\n";
  }
' app/controllers/*.ts app/services/*.ts 2>/dev/null \
  | grep -v "document_service\.ts\|admin_wrapped_service\.ts\|wrapped_service\.ts" || true)
if [ -n "$DOC_NO_SOFT" ]; then
  C=$(echo "$DOC_NO_SOFT" | wc -l | tr -d ' \r')
  CONV_HITS=$((CONV_HITS + C))
  CONV_DETAILS="${CONV_DETAILS}  [SoftDelete] $C Document.query() sans .whereNull('deletedAt') (canonical-skip:soft-delete pour opt-out)"$'\n'
fi

# ── E. Public branding : canonical = BrandingService.loadPublicBranding ─────
# Detect controllers publics qui calculent un brandLogo/brandName a la main
# (lecture directe user.company?.logo) sans passer par BrandingService.
# Multi-ligne car les annotations canonical-skip:branding sont sur la ligne
# au-dessus du code (mono-ligne grep raterait).
BRAND_RAW=$(perl -0777 -ne '
  while (/(?:user|gallery\.user)\??\.company\??\.logo/g) {
    my $pos = $-[0];
    my $idx = $pos;
    # Walk back 10 newlines pour englober une annotation comment multi-ligne
    for (my $i = 0; $i < 10; $i++) { my $prev = rindex($_, "\n", $idx - 1); last if $prev < 0; $idx = $prev; }
    my $context = substr($_, $idx, $pos - $idx);
    next if $context =~ /canonical-skip:branding/;
    next if $context =~ /BrandingService\.loadPublicBranding/;
    my $line = (substr($_, 0, $pos) =~ tr/\n//) + 1;
    print "$ARGV:$line\n";
  }
' app/controllers/public_*.ts 2>/dev/null \
  | grep -v "og_image_controller" || true)
if [ -n "$BRAND_RAW" ]; then
  C=$(echo "$BRAND_RAW" | wc -l | tr -d ' \r')
  CONV_HITS=$((CONV_HITS + C))
  CONV_DETAILS="${CONV_DETAILS}  [Branding] $C reads user.company.logo directly (canonical: BrandingService.loadPublicBranding — respecte PLG)"$'\n'
fi

# ── F. fire-and-forget promises : canonical = swallow() helper ──────────────
# Audit 2026-04-15 a corrige 81 sites — la regex catch les .catch(() => {})
# avec arg vide ou un seul ident, body vide. Voir docs/anti-patterns.md.
FAF_RAW=$(grep -rnE "\.catch\(\(?[a-z_]*\)? *=> *\{\}\)" app/controllers/ app/services/ --include="*.ts" 2>/dev/null \
  | grep -v "//.*canonical-skip:swallow" || true)
if [ -n "$FAF_RAW" ]; then
  C=$(echo "$FAF_RAW" | wc -l | tr -d ' \r')
  CONV_HITS=$((CONV_HITS + C))
  CONV_DETAILS="${CONV_DETAILS}  [Swallow] $C raw .catch(() => {}) (canonical: import swallow from '#helpers/swallow'; .catch(swallow('op_name')))"$'\n'
fi

# ── Verdict ────────────────────────────────────────────────────────────────
if [ $CONV_HITS -eq 0 ]; then
  pass "All conventions respected (OG/Storage/Auth/SoftDelete/Branding/Swallow)"
else
  warn "$CONV_HITS convention divergence(s) — review or annotate '// canonical-skip:<rule>:<reason>'"
  printf '%s' "$CONV_DETAILS" | head -12
fi

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

# ── 24. SBOM generation (CycloneDX 1.6 — front + back) ─────────────────────
# Genere reports/sbom.cdx.json couvrant tout npm + 4 composants CDN (Alpine + Turbo).
# Le SBOM est un artefact reproductible (gitignore reports/), genere a chaque scan.
# Failure = WARN, pas FAIL (la generation peut planter sur reseau lent sans bloquer un push).
step 24 "SBOM generation (CycloneDX 1.6)" 3 "Supply chain"
if [ -x scripts/generate-sbom.sh ]; then
  if SBOM_OUT=$(bash scripts/generate-sbom.sh 2>&1); then
    SBOM_COMP=$(jq -r '.components | length' reports/sbom.cdx.json 2>/dev/null || echo "?")
    pass "reports/sbom.cdx.json — $SBOM_COMP components (npm + CDN-loaded Alpine/Turbo)"
  else
    warn "SBOM generation failed (network? cdxgen?) — see scripts/generate-sbom.sh"
    echo "$SBOM_OUT" | tail -3 | while IFS= read -r line; do echo "    $line"; done
  fi
else
  warn "scripts/generate-sbom.sh missing or not executable"
fi

# ============================================================================
# Pre-deployment hardening (steps 25-29) — checklist OWASP A01/A04/A05/A07
# Aligned: https://owasp.org/Top10/A01_2021-Broken_Access_Control/
# Catalogue : voir docs/security-multitenant.md §Pre-deployment
# ============================================================================

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

# ── 26. CORS — locked to own domains (not '*' in production) ───────────────
# Browser-side protection : la config CORS doit lister explicitement les origins
# autorisés. '*' en prod = malveillant site peut lire les responses depuis le
# browser de la victime (cf OWASP A05).
step 26 "CORS configuration (origin lock)" 2 "A05 Misconfig"
CORS_FILES=$(ls config/cors.ts start/cors.ts 2>/dev/null || true)
# Detect API cross-origin endpoints : si le projet n'a que des routes
# /api/* avec Bearer token auth ET pas de @adonisjs/cors → SPA same-domain,
# CORS pas requis. Si /api/* présent + pas de config CORS → vrai gap.
CROSS_ORIGIN_API=$(grep -rln "router\.group.*'/api'\|prefix:\s*['\"]\/api" start/routes.ts start/routes/ 2>/dev/null || true)
if [ -z "$CORS_FILES" ]; then
  if [ -z "$CROSS_ORIGIN_API" ]; then
    pass "No CORS config required — same-origin SPA (no /api cross-origin routes detected)"
  else
    warn "config/cors.ts missing but /api routes detected — verify @adonisjs/cors if external clients consume API"
  fi
else
  CORS_STAR=""
  for f in $CORS_FILES; do
    # Detect origin: '*' OU origin: true sans whitelist conditionnelle
    STAR_FOUND=$(grep -nE "origin:\s*['\"]\\*['\"]|origin:\s*true\s*[,}]" "$f" 2>/dev/null | grep -v "//.*canonical-skip:cors" || true)
    if [ -n "$STAR_FOUND" ]; then
      CORS_STAR="${CORS_STAR}${STAR_FOUND}"$'\n'
    fi
  done
  CORS_STAR=$(printf '%s' "$CORS_STAR" | grep -v '^$' || true)
  if [ -z "$CORS_STAR" ]; then
    pass "CORS origins locked (no wildcard '*' or unconditional true)"
  else
    fail "CORS wildcard detected — lock to APP_URL whitelist in production"
    echo "$CORS_STAR" | head -3 | while IFS= read -r line; do echo "    $line"; done
  fi
fi

# ── 27. Rate limit on critical auth endpoints ──────────────────────────────
# Login / forgot_password / signup doivent avoir un throttle plus serré que
# le global IP throttle (300/min). Brute-force + credential stuffing.
step 27 "Rate limit on auth-critical endpoints" 2 "A07 Auth"
# Detection v2 : pattern PicStudio = controllers auth/*_controller.ts +
# dedicated throttles (authThrottle, signupThrottle, passwordResetThrottle)
# dans start/limiter.js + applied via .middleware() sur routes auth.
AUTH_CTRLS=$(ls app/controllers/auth/*.ts 2>/dev/null | head -5 || true)
DEDICATED_THROTTLES=$(grep -rnE "authThrottle|signupThrottle|passwordResetThrottle|loginThrottle" start/ 2>/dev/null | head -5 || true)
GLOBAL_THROTTLE_MW=$(ls app/middleware/global_throttle_middleware.ts 2>/dev/null || true)
if [ -z "$AUTH_CTRLS" ]; then
  skip "No auth controllers detected (app/controllers/auth/*.ts)"
else
  # 3 conditions de bonne santé : (a) auth controllers présents (b) throttles
  # dédiés définis (c) global throttle pour defense-in-depth
  if [ -n "$DEDICATED_THROTTLES" ] && [ -n "$GLOBAL_THROTTLE_MW" ]; then
    pass "Dedicated throttles (auth/signup/passwordReset) + global IP throttle (defense-in-depth)"
  elif [ -n "$GLOBAL_THROTTLE_MW" ]; then
    warn "Global throttle present but no dedicated auth throttles — verify login/signup/reset have stricter limits than 300/min/IP"
  else
    fail "Rate limit middleware MISSING — install @adonisjs/limiter + add throttles to auth routes"
  fi
fi

# ── 28. Production error handling (debug off + custom error pages) ─────────
# Default debug pages (stack trace, env, file paths) = info disclosure massive.
# handler.ts doit avoir `debug = !inProduction` ET pages d'erreur custom.
step 28 "Production error handling (no stack trace leak)" 2 "A05 Misconfig"
HANDLER_FILE="app/exceptions/handler.ts"
if [ ! -f "$HANDLER_FILE" ]; then
  fail "$HANDLER_FILE not found — Adonis exception handler missing"
else
  DEBUG_GUARD=$(grep -n "debug.*inProduction\|debug.*=.*!.*production\|debug:.*!app\.inProduction" "$HANDLER_FILE" 2>/dev/null || true)
  RENDER_STATUS=$(grep -n "renderStatusPages.*inProduction\|renderStatusPages.*=.*app\.inProduction" "$HANDLER_FILE" 2>/dev/null || true)
  CUSTOM_500=$(ls resources/views/pages/errors/server_error.edge resources/views/errors/server_error.edge 2>/dev/null | head -1 || true)
  CUSTOM_404=$(ls resources/views/pages/errors/not_found.edge resources/views/errors/not_found.edge 2>/dev/null | head -1 || true)
  ISSUES=""
  [ -z "$DEBUG_GUARD" ] && ISSUES="${ISSUES}    - debug flag not tied to app.inProduction"$'\n'
  [ -z "$RENDER_STATUS" ] && ISSUES="${ISSUES}    - renderStatusPages not tied to app.inProduction"$'\n'
  [ -z "$CUSTOM_500" ] && ISSUES="${ISSUES}    - custom 500 page missing (pages/errors/server_error.edge)"$'\n'
  [ -z "$CUSTOM_404" ] && ISSUES="${ISSUES}    - custom 404 page missing (pages/errors/not_found.edge)"$'\n'
  if [ -z "$ISSUES" ]; then
    pass "Debug off in prod + custom error pages present (server_error + not_found)"
  else
    fail "Production error handling gaps:"
    printf '%s' "$ISSUES"
  fi
fi

# ── 29. DB indexes — foreign keys covered ──────────────────────────────────
# Sans index, FK lookups deviennent seq scans = lock + connection pool exhausted
# en prod. Audit migrations : chaque .foreign() doit avoir une .index() adjacente
# OU être sur une PK (déjà indexed) OU être annoté canonical-skip:db-index.
step 29 "DB indexes — foreign keys covered" 3 "Performance"
FK_GAPS=$(perl -0777 -ne '
  while (/\.foreign\(\s*["\x27]([a-z_]+)["\x27]/g) {
    my $col = $1;
    my $pos = $-[0];
    # Skip si colonne contient "id" suivi de plus rien (= PK ou auto-indexed)
    next if $col eq "id";
    # Skip si .index() apparait dans 200 chars autour (avant ou apres .foreign)
    my $window_start = $pos > 200 ? $pos - 200 : 0;
    my $window_end = $pos + 200 < length($_) ? $pos + 200 : length($_);
    my $context = substr($_, $window_start, $window_end - $window_start);
    next if $context =~ /\.index\(\s*\[?["\x27]?$col/;
    next if $context =~ /canonical-skip:db-index/;
    # Skip si la table elle-meme a un index composite sur cette FK (heuristique)
    next if $context =~ /createIndex.*$col|CREATE\s+INDEX.*$col/i;
    my $line = (substr($_, 0, $pos) =~ tr/\n//) + 1;
    print "$ARGV:$line:$col\n";
  }
' database/migrations/*.ts 2>/dev/null | head -20 || true)
if [ -z "$FK_GAPS" ]; then
  pass "All foreign keys appear indexed (or annotated canonical-skip:db-index)"
else
  C=$(echo "$FK_GAPS" | wc -l | tr -d ' \r')
  warn "$C foreign key(s) may lack covering index (audit with EXPLAIN ANALYZE if hot path)"
  echo "$FK_GAPS" | head -5 | while IFS= read -r line; do echo "    $line"; done
fi

# ── 30. Shield headers (CSP + HSTS + X-Frame + X-Content-Type) ─────────────
# CSP / HSTS / X-Frame-Options / X-Content-Type-Options = defense-in-depth XSS
# amplification + clickjacking + MIME sniff. Config canonical : @adonisjs/shield
# dans config/shield.ts avec policy explicite (pas 'unsafe-inline' global).
step 30 "Security headers (Shield CSP/HSTS/X-Frame/MIME)" 2 "A05 Misconfig"
SHIELD_FILE="config/shield.ts"
if [ ! -f "$SHIELD_FILE" ]; then
  fail "config/shield.ts MISSING — @adonisjs/shield required for production headers"
else
  HEADER_GAPS=""
  # CSP : doit avoir directives explicites (pas juste enabled: true sans policy)
  CSP_PRESENT=$(grep -nE "csp:\s*\{" "$SHIELD_FILE" 2>/dev/null || true)
  if [ -z "$CSP_PRESENT" ]; then
    HEADER_GAPS="${HEADER_GAPS}    - CSP block missing in shield.ts"$'\n'
  else
    # 'unsafe-inline' acceptable uniquement avec annotation justifiée
    UNSAFE_INLINE=$(grep -nE "unsafe-inline" "$SHIELD_FILE" 2>/dev/null \
      | grep -v "canonical-skip:csp" || true)
    if [ -n "$UNSAFE_INLINE" ]; then
      HEADER_GAPS="${HEADER_GAPS}    - CSP 'unsafe-inline' present (annotate canonical-skip:csp:<reason> if intentional)"$'\n'
    fi
  fi
  # HSTS : enabled obligatoire en prod
  HSTS_PRESENT=$(grep -nE "hsts:\s*\{" "$SHIELD_FILE" 2>/dev/null || true)
  if [ -z "$HSTS_PRESENT" ]; then
    HEADER_GAPS="${HEADER_GAPS}    - HSTS block missing (transport-layer protection)"$'\n'
  fi
  # X-Frame-Options : protection clickjacking
  XFRAME_PRESENT=$(grep -nE "xFrame:\s*\{|x-frame" "$SHIELD_FILE" 2>/dev/null || true)
  if [ -z "$XFRAME_PRESENT" ]; then
    HEADER_GAPS="${HEADER_GAPS}    - X-Frame-Options block missing (clickjacking protection)"$'\n'
  fi
  # X-Content-Type-Options : MIME sniff protection (généralement 'noSniff: true')
  NOSNIFF_PRESENT=$(grep -nE "noSniff\s*:|contentTypeSniffing" "$SHIELD_FILE" 2>/dev/null || true)
  if [ -z "$NOSNIFF_PRESENT" ]; then
    HEADER_GAPS="${HEADER_GAPS}    - X-Content-Type-Options noSniff missing"$'\n'
  fi
  if [ -z "$HEADER_GAPS" ]; then
    pass "Shield headers configured (CSP + HSTS + X-Frame + noSniff)"
  else
    fail "Shield headers gaps:"
    printf '%s' "$HEADER_GAPS"
  fi
fi

# ── 31. Webhook signature verification (Stripe + NotchPay) ─────────────────
# Webhooks money endpoints = vecteur replay attack. Stripe.webhooks.constructEvent
# OU verification HMAC NotchPay obligatoire AVANT business logic. Anti-pattern :
# controller webhook accepte payload sans verifier header signature.
step 31 "Webhook signature verification (money endpoints)" 1 "A04 Insecure Design"
WEBHOOK_FILES=$(grep -rln "stripe-signature\|notch-signature\|x-notchpay-signature\|webhook" app/controllers/ --include="*.ts" 2>/dev/null \
  | grep -iE "webhook|hook" | head -10 || true)
if [ -z "$WEBHOOK_FILES" ]; then
  skip "No webhook controllers detected"
else
  WEBHOOK_GAPS=""
  for f in $WEBHOOK_FILES; do
    # Détecte fichiers webhook qui font des INSERT/UPDATE/SAVE/PAYMENT sans
    # vérification signature préalable (constructEvent / verifyWebhook / HMAC verify)
    HAS_BUSINESS_LOGIC=$(grep -cE "\.save\(\)|\.create\(|\.update\(|PaymentService|InvoiceService|markAsPaid|fulfillOrder" "$f" 2>/dev/null || echo "0")
    HAS_SIG_CHECK=$(grep -cE "constructEvent|verifyWebhook|verifyHmac|crypto\.timingSafeEqual|signature\s*===|webhookSecret" "$f" 2>/dev/null || echo "0")
    if [ "$HAS_BUSINESS_LOGIC" -gt 0 ] && [ "$HAS_SIG_CHECK" -eq 0 ]; then
      WEBHOOK_GAPS="${WEBHOOK_GAPS}    - $f : business logic without signature check"$'\n'
    fi
  done
  WEBHOOK_GAPS=$(printf '%s' "$WEBHOOK_GAPS" | grep -v '^$' || true)
  if [ -z "$WEBHOOK_GAPS" ]; then
    NB=$(echo "$WEBHOOK_FILES" | wc -l | tr -d ' \r')
    pass "$NB webhook controller(s) verify signature before business logic"
  else
    fail "Webhook signature verification missing:"
    printf '%s' "$WEBHOOK_GAPS"
  fi
fi

# ════════════════════════════════════════════════════════════════════════════
# Summary — graduated by tier + top risks
# ════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
echo -e "  ${BOLD}Pre-push Security Scan — Tier Summary${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"
printf "  ${RED}${BOLD}TIER 1 BLOCKER${NC}    %s   ${GREEN}PASS %2d${NC}  ${RED}FAIL %2d${NC}  ${YELLOW}WARN %2d${NC}\n" \
  "(A01/A02/A03/A04)" $T1_PASS $T1_FAIL $T1_WARN
printf "  ${YELLOW}${BOLD}TIER 2 IMPORTANT${NC}  %s        ${GREEN}PASS %2d${NC}  ${RED}FAIL %2d${NC}  ${YELLOW}WARN %2d${NC}\n" \
  "(A05/A07/A09)" $T2_PASS $T2_FAIL $T2_WARN
printf "  ${BLUE}${BOLD}TIER 3 ADVISORY${NC}   %s         ${GREEN}PASS %2d${NC}  ${RED}FAIL %2d${NC}  ${YELLOW}WARN %2d${NC}\n" \
  "(Supply / Quality / Conv)" $T3_PASS $T3_FAIL $T3_WARN
echo -e "${BOLD}─────────────────────────────────────────────────────────────────────${NC}"
printf "  ${BOLD}TOTAL${NC}            ${GREEN}PASS: %2d${NC}  ${RED}FAIL: %2d${NC}  ${YELLOW}WARN: %2d${NC}\n" $PASS $FAIL $WARN
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════════${NC}"

# Top risks open (T1+T2 only — T3 warn = dette, pas insight actionnable)
if [ -n "$TOP_RISKS" ]; then
  echo ""
  echo -e "${BOLD}Top risks open (Tier 1+2):${NC}"
  printf '%s' "$TOP_RISKS" | head -8 | while IFS= read -r line; do
    [ -n "$line" ] && echo -e "  ${RED}•${NC} $line"
  done
fi

# Verdict graduel : T1 FAIL = BLOCKED. T2 FAIL = NEEDS REVIEW. T3 only FAIL = SHIP with debt.
echo ""
if [ $T1_FAIL -gt 0 ]; then
  echo -e "${RED}${BOLD}🔴 BLOCKED${NC} — $T1_FAIL Tier-1 BLOCKER fail(s). Fix before push (data leak / RCE risk)."
  exit 1
elif [ $T2_FAIL -gt 0 ]; then
  echo -e "${YELLOW}${BOLD}🟡 NEEDS REVIEW${NC} — $T2_FAIL Tier-2 IMPORTANT fail(s). Fix before merge."
  exit 1
elif [ $FAIL -gt 0 ]; then
  echo -e "${YELLOW}${BOLD}🟡 SHIP WITH DEBT${NC} — $FAIL Tier-3 ADVISORY fail(s). Track in roadmap."
  exit 1
else
  echo -e "${GREEN}${BOLD}🟢 READY TO PUSH${NC}"
  exit 0
fi
