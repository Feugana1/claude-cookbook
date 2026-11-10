#!/usr/bin/env bash
# ============================================================================
# scan-prod-readiness.sh — Discovery bash pour skill /prod-readiness V0
#
# Usage :
#   bash scan-prod-readiness.sh [path]           # sortie JSON (défaut)
#   bash scan-prod-readiness.sh [path] --human   # sortie human-readable
#
# Rôle : signals détection pure (read-only). Le skill /prod-readiness lit
# ce JSON puis fait matching capabilities → gap → score → recommandations.
# Ce script NE FAIT PAS de scoring — juste discovery.
# ============================================================================

set -euo pipefail

TARGET="${1:-.}"
[ "$TARGET" = "--human" ] && { TARGET="."; MODE=human; } || MODE="${MODE:-json}"
[ "${2:-}" = "--human" ] && MODE=human
TARGET="$(cd "$TARGET" && pwd)"

# ── Helpers ────────────────────────────────────────────────────────────────

# Match dep in package.json (supports scoped + wildcards)
has_dep() {
  local pattern="$1"
  local pkg="$TARGET/package.json"
  [ -f "$pkg" ] || return 1
  # Escape regex, convert * to .*
  local re=$(printf '%s' "$pattern" | sed 's|/|\\/|g; s|\*|[^"]*|g')
  grep -qE "\"$re\":" "$pkg"
}

has_file() { [ -f "$TARGET/$1" ]; }
has_dir_nonempty() { [ -d "$TARGET/$1" ] && [ -n "$(ls -A "$TARGET/$1" 2>/dev/null || true)" ]; }
has_env_var() {
  local var="$1"
  for f in "$TARGET/.env.example" "$TARGET/.env" "$TARGET/.env.local" "$TARGET/.env.production"; do
    [ -f "$f" ] && grep -qE "^${var}=" "$f" 2>/dev/null && return 0
  done
  return 1
}
file_grep() {
  local file="$1" pattern="$2"
  [ -f "$TARGET/$file" ] || return 1
  grep -qE "$pattern" "$TARGET/$file" 2>/dev/null
}

# ── Signals collection ────────────────────────────────────────────────────

declare -a SIGNALS_JSON

add_signal() {
  local domain="$1" name="$2" evidence="$3"
  # JSON-safe escape
  local ev_esc=$(printf '%s' "$evidence" | sed 's/\\/\\\\/g; s/"/\\"/g')
  SIGNALS_JSON+=("{\"domain\":\"$domain\",\"signal\":\"$name\",\"evidence\":\"$ev_esc\"}")
}

# ---------------- SECURITY ------------------------------------------------

# TLS
file_grep "next.config.js" "redirects.*https" && add_signal security tls_config "next.config.js redirects to https"
file_grep "next.config.mjs" "redirects.*https" && add_signal security tls_config "next.config.mjs redirects to https"
file_grep "vercel.json" "https" && add_signal security tls_config "vercel.json enforces https"
has_file "wrangler.toml" && add_signal security tls_platform "cloudflare-workers auto-TLS"
has_file "vercel.json" || has_file ".vercel/project.json" && add_signal security tls_platform "vercel auto-TLS"
has_file "netlify.toml" && add_signal security tls_platform "netlify auto-TLS"

# Auth
for d in '@auth/*' 'next-auth' '@adonisjs/auth' 'passport' 'lucia' '@clerk/*' '@auth0/*' '@supabase/auth-helpers-*'; do
  has_dep "$d" && add_signal security auth_dep "dep: $d"
done

# Secrets
has_file ".env.example" && add_signal security secrets_env_example ".env.example present"
has_dep "dotenv" && add_signal security secrets_dep "dep: dotenv"

# Security headers
has_dep "helmet" && add_signal security headers_dep "dep: helmet"
file_grep "next.config.js" "Strict-Transport-Security" && add_signal security headers_config "HSTS in next.config.js"

# Rate limiting
for d in 'express-rate-limit' '@upstash/ratelimit' 'rate-limiter-flexible'; do
  has_dep "$d" && add_signal security ratelimit_dep "dep: $d"
done

# Dep scanning
has_file ".github/dependabot.yml" && add_signal security depscan_dependabot "dependabot config"
f=$(find "$TARGET/.github/workflows" -type f -exec grep -l "trivy\|snyk\|npm audit" {} + 2>/dev/null | head -1 || true)
[ -n "$f" ] && add_signal security depscan_workflow "workflow: $(basename "$f")"

# Input validation
for d in 'zod' 'joi' 'yup' '@vinejs/vine' 'valibot' 'class-validator'; do
  has_dep "$d" && add_signal security input_validation_dep "dep: $d"
done

# ---------------- RELIABILITY ---------------------------------------------

# DB backup
f=$(find "$TARGET" -maxdepth 3 -type f -name "*.tf" -exec grep -l "backup_retention_period\|aws_backup_plan" {} \; 2>/dev/null | head -1 || true)
[ -n "$f" ] && add_signal reliability db_backup_iac "terraform: $f"
f=$(find "$TARGET" -maxdepth 2 -type f \( -name "backup.sh" -o -name "db-backup*.sh" -o -name "pg-backup*.sh" \) 2>/dev/null | head -1 || true)
[ -n "$f" ] && add_signal reliability db_backup_script "script: $(basename "$f")"
f=$(find "$TARGET/.github/workflows" -type f -exec grep -l "backup" {} \; 2>/dev/null | head -1 || true)
[ -n "$f" ] && add_signal reliability db_backup_workflow "workflow: $(basename "$f")"
# Managed DB detection via DATABASE_URL host
for f in "$TARGET/.env.example" "$TARGET/.env"; do
  [ -f "$f" ] || continue
  grep -q "supabase.co\|neon.tech\|planetscale.io\|railway\|render.com\|amazonaws.com/rds" "$f" 2>/dev/null && \
    add_signal reliability db_backup_managed "managed DB in $(basename $f)"
done

# Health checks
code_dirs=()
for d in app src pages routes api; do [ -d "$TARGET/$d" ] && code_dirs+=("$TARGET/$d"); done
if [ ${#code_dirs[@]} -gt 0 ]; then
  if grep -rE "'/(health|healthz|ready)'" --include="*.ts" --include="*.js" "${code_dirs[@]}" >/dev/null 2>&1; then
    add_signal reliability health_check_route "health route present"
  fi
fi
f=$(find "$TARGET" -maxdepth 3 -type f \( -name "*.yaml" -o -name "*.yml" \) -exec grep -l "livenessProbe\|readinessProbe" {} \; 2>/dev/null | head -1 || true)
[ -n "$f" ] && add_signal reliability health_check_k8s "k8s probe: $(basename "$f")"

# Retry/backoff
for d in 'p-retry' 'async-retry' 'exponential-backoff' 'axios-retry'; do
  has_dep "$d" && add_signal reliability retry_dep "dep: $d"
done

# ---------------- OBSERVABILITY -------------------------------------------

# Error tracking
for d in '@sentry/*' 'rollbar' '@bugsnag/*' '@honeybadger-io/*'; do
  has_dep "$d" && add_signal observability error_tracking_dep "dep: $d"
done
for e in SENTRY_DSN ROLLBAR_TOKEN BUGSNAG_API_KEY; do
  has_env_var "$e" && add_signal observability error_tracking_env "env: $e"
done
while IFS= read -r f; do
  [ -n "$f" ] && add_signal observability error_tracking_config "config: $(basename "$f")"
done < <(find "$TARGET" -maxdepth 2 -type f -name "sentry*.config.*" 2>/dev/null | head -3 || true)

# Logs
for d in 'pino' 'winston' 'bunyan'; do
  has_dep "$d" && add_signal observability logs_dep "dep: $d"
done
has_env_var "LOG_LEVEL" && add_signal observability logs_env "env: LOG_LEVEL"

# Metrics
has_dep "prom-client" && add_signal observability metrics_dep "dep: prom-client"
has_dep "@opentelemetry/*" && add_signal observability otel_dep "dep: @opentelemetry/*"

# Uptime — heuristic sur README
has_file "README.md" && grep -qEi "better.?uptime|uptime.?robot|pingdom|checkly|healthchecks\.io|statuspage" "$TARGET/README.md" 2>/dev/null && \
  add_signal observability uptime_readme "uptime service mentioned in README"

# Alerting
for e in PAGERDUTY_TOKEN OPSGENIE_API_KEY SLACK_WEBHOOK SLACK_WEBHOOK_URL; do
  has_env_var "$e" && add_signal observability alerting_env "env: $e"
done

# ---------------- DELIVERY -----------------------------------------------

# CI
has_dir_nonempty ".github/workflows" && add_signal delivery ci_github "github workflows dir"
has_file ".gitlab-ci.yml" && add_signal delivery ci_gitlab "gitlab-ci.yml"
has_file ".circleci/config.yml" && add_signal delivery ci_circle "circleci"
has_file "Jenkinsfile" && add_signal delivery ci_jenkins "Jenkinsfile"

# CD
f=$(find "$TARGET/.github/workflows" -type f -exec grep -l "deploy\|release" {} \; 2>/dev/null | head -1 || true)
[ -n "$f" ] && add_signal delivery cd_workflow "workflow: $(basename "$f")"
for f in vercel.json netlify.toml fly.toml railway.json wrangler.toml; do
  has_file "$f" && add_signal delivery cd_platform "$f present"
done

# Rollback
f=$(find "$TARGET/.github/workflows" -type f -exec grep -l "rollback" {} \; 2>/dev/null | head -1 || true)
[ -n "$f" ] && add_signal delivery rollback_workflow "workflow: $(basename "$f")"

# IaC
for d in terraform pulumi cdk helm k8s; do
  has_dir_nonempty "$d" && add_signal delivery iac_dir "$d/ dir"
done
for f in serverless.yml wrangler.toml fly.toml railway.json; do
  has_file "$f" && add_signal delivery iac_file "$f present"
done

# Multi-envs
for f in .env.staging .env.preview .env.production; do
  has_file "$f" && add_signal delivery multi_env "$f present"
done

# Feature flags
for d in 'launchdarkly-*' '@growthbook/*' 'unleash-*' '@statsig/*' 'posthog-node'; do
  has_dep "$d" && add_signal delivery feature_flags_dep "dep: $d"
done

# ---------------- DATA ---------------------------------------------------

# Managed DB (déjà détecté supra via URL host)

# Migrations
for d in "database/migrations" "prisma/migrations" "drizzle"; do
  has_dir_nonempty "$d" && add_signal data migrations_dir "$d/ present"
done
for d in 'knex' '@adonisjs/lucid' 'typeorm' '@prisma/*' 'drizzle-orm'; do
  has_dep "$d" && add_signal data migrations_orm_dep "dep: $d"
done

# Storage
for d in '@aws-sdk/client-s3' '@google-cloud/storage' '@azure/storage-blob' '@supabase/storage-*' '@vercel/blob'; do
  has_dep "$d" && add_signal data storage_dep "dep: $d"
done
for e in S3_BUCKET STORAGE_URL AWS_S3_BUCKET; do
  has_env_var "$e" && add_signal data storage_env "env: $e"
done

# Cache
for d in 'redis' 'ioredis' '@upstash/redis' 'node-cache'; do
  has_dep "$d" && add_signal data cache_dep "dep: $d"
done
has_env_var "REDIS_URL" && add_signal data cache_env "env: REDIS_URL"

# PII docs
for f in docs/privacy.md docs/gdpr.md docs/data-retention.md; do
  has_file "$f" && add_signal data pii_doc "$f present"
done

# ---------------- OUTPUT ─────────────────────────────────────────────────

if [ "$MODE" = "human" ]; then
  echo "=== Prod-readiness discovery : $TARGET ==="
  echo ""
  for line in "${SIGNALS_JSON[@]}"; do
    domain=$(echo "$line" | sed 's/.*"domain":"\([^"]*\)".*/\1/')
    signal=$(echo "$line" | sed 's/.*"signal":"\([^"]*\)".*/\1/')
    evidence=$(echo "$line" | sed 's/.*"evidence":"\([^"]*\)".*/\1/')
    printf "  [%-14s] %-30s — %s\n" "$domain" "$signal" "$evidence"
  done
  echo ""
  echo "Total signals : ${#SIGNALS_JSON[@]}"
else
  # JSON output
  echo "{"
  echo "  \"target\": \"$TARGET\","
  echo "  \"scanner_version\": \"0.1.0\","
  echo "  \"signals\": ["
  n=${#SIGNALS_JSON[@]}
  for i in "${!SIGNALS_JSON[@]}"; do
    printf "    %s" "${SIGNALS_JSON[$i]}"
    [ "$i" -lt "$((n - 1))" ] && echo "," || echo ""
  done
  echo "  ],"
  echo "  \"signal_count\": ${#SIGNALS_JSON[@]}"
  echo "}"
fi
