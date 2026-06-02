#!/usr/bin/env bash
# ============================================================================
# PicStudio — SBOM generator (CycloneDX 1.6)
# ----------------------------------------------------------------------------
# Generates a Software Bill of Materials covering BOTH:
#   - Back (AdonisJS, Lucid, BullMQ, Vine, etc.) via package-lock.json
#   - Front toolchain (Vite, Rollup, Tailwind) via devDependencies
#   - Front runtime (Alpine.js + plugins + Turbo) via CDN patch
#     — these are loaded by jsdelivr/unpkg and NOT in package-lock.json
#       (cf. CLAUDE.md §5: pinned CDN versions Alpine @3.14.9, Turbo @8.0.4)
#
# Output: reports/sbom.cdx.json
# Usage:  bash scripts/generate-sbom.sh
#
# CDN hashes are pinned. To rotate after a CDN version bump, re-fetch + recompute:
#   curl -sSL <url> | shasum -a 256
#   curl -sSL <url> | shasum -a 384
#   curl -sSL <url> | shasum -a 512
# ============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="reports/sbom.cdx.json"
mkdir -p reports

# --- 1. npm tree via cdxgen ------------------------------------------------
echo "→ cdxgen scanning npm dependencies..."
npx --yes @cyclonedx/cdxgen@latest \
  -t nodejs \
  -o "$OUT" \
  --spec-version 1.6 \
  --no-recurse \
  . > /dev/null 2>&1

# --- 2. CDN patch: Alpine + Turbo (not in package-lock.json) ---------------
TMP="$(mktemp -d)"
trap "rm -rf $TMP" EXIT

cat > "$TMP/patch.json" <<'PATCH_EOF'
[
  {
    "type": "library",
    "bom-ref": "pkg:npm/alpinejs@3.14.9",
    "name": "alpinejs",
    "version": "3.14.9",
    "purl": "pkg:npm/alpinejs@3.14.9",
    "scope": "required",
    "description": "Frontend framework, loaded at runtime via CDN (cdn.jsdelivr.net). Not present in package-lock.json.",
    "licenses": [{ "license": { "id": "MIT" } }],
    "externalReferences": [
      { "type": "distribution", "url": "https://cdn.jsdelivr.net/npm/alpinejs@3.14.9/dist/cdn.min.js" },
      { "type": "website",      "url": "https://alpinejs.dev" },
      { "type": "vcs",          "url": "https://github.com/alpinejs/alpine" }
    ],
    "hashes": [
      { "alg": "SHA-256", "content": "3ed1eed252488921df65e363d6715deb04d7f92aaedb9e52199fdf73cb1e0ad3" },
      { "alg": "SHA-384", "content": "f40c773264bd002971272779ff369f7175e3c66c0585909db13e872682636abbc2680909964e500f38cb266f96771e45" },
      { "alg": "SHA-512", "content": "2927627946314b1aff95a077061e533fc1809e0e3d6f6a917dd72716f87c3ae3e93e092c035f3d390f6fd40de0233e4ff6cdc0e1a5cc7b9ba21cb31f95aeb453" }
    ],
    "properties": [
      { "name": "cdx:npm:package_name",        "value": "alpinejs" },
      { "name": "picstudio:delivery_channel",  "value": "cdn" },
      { "name": "picstudio:cdn_provider",      "value": "jsdelivr" }
    ]
  },
  {
    "type": "library",
    "bom-ref": "pkg:npm/@alpinejs/collapse@3.14.9",
    "group": "@alpinejs",
    "name": "collapse",
    "version": "3.14.9",
    "purl": "pkg:npm/%40alpinejs/collapse@3.14.9",
    "scope": "required",
    "description": "Alpine plugin (collapse), loaded at runtime via CDN. Not present in package-lock.json.",
    "licenses": [{ "license": { "id": "MIT" } }],
    "externalReferences": [
      { "type": "distribution", "url": "https://cdn.jsdelivr.net/npm/@alpinejs/collapse@3.14.9/dist/cdn.min.js" },
      { "type": "website",      "url": "https://alpinejs.dev/plugins/collapse" },
      { "type": "vcs",          "url": "https://github.com/alpinejs/alpine" }
    ],
    "hashes": [
      { "alg": "SHA-256", "content": "c7661d4e2cf0465e3cd693190debb5f592ac72dcc4cfe650581273767558b27b" },
      { "alg": "SHA-384", "content": "340acdc335ac51217e918da5816e18ae21248cbaa2f89fb36ba1eb10d527ff79d9aa406759bc55db69022442b952eea7" },
      { "alg": "SHA-512", "content": "63fea6219e0920c6801a4b5ca40582c6e08efc2712148806394f9fadea2816a499e7cb45b315b82702954a1429ba2b01367afa7dfce43e465ce50e5113f05f52" }
    ],
    "properties": [
      { "name": "cdx:npm:package_name",        "value": "@alpinejs/collapse" },
      { "name": "picstudio:delivery_channel",  "value": "cdn" },
      { "name": "picstudio:cdn_provider",      "value": "jsdelivr" }
    ]
  },
  {
    "type": "library",
    "bom-ref": "pkg:npm/@alpinejs/focus@3.14.9",
    "group": "@alpinejs",
    "name": "focus",
    "version": "3.14.9",
    "purl": "pkg:npm/%40alpinejs/focus@3.14.9",
    "scope": "required",
    "description": "Alpine plugin (focus), loaded at runtime via CDN. Not present in package-lock.json.",
    "licenses": [{ "license": { "id": "MIT" } }],
    "externalReferences": [
      { "type": "distribution", "url": "https://cdn.jsdelivr.net/npm/@alpinejs/focus@3.14.9/dist/cdn.min.js" },
      { "type": "website",      "url": "https://alpinejs.dev/plugins/focus" },
      { "type": "vcs",          "url": "https://github.com/alpinejs/alpine" }
    ],
    "hashes": [
      { "alg": "SHA-256", "content": "0326aee04b8abdaed23caba37025291a5b81a812daf938128bfe1e44845573ef" },
      { "alg": "SHA-384", "content": "6ca5cd53ba36637524fc5d8f07a5346ccc8665fea92c39de3ccef453bb13137717510f892e0cebaff9308a9121d29db7" },
      { "alg": "SHA-512", "content": "71b9dbe912de1fa31022762915368166122faa85754903024fb812fe5733e54e446e27d1a35c873a50c764e3f48bfda8a3b1bdad2369486baa1dd2b78c1caad9" }
    ],
    "properties": [
      { "name": "cdx:npm:package_name",        "value": "@alpinejs/focus" },
      { "name": "picstudio:delivery_channel",  "value": "cdn" },
      { "name": "picstudio:cdn_provider",      "value": "jsdelivr" }
    ]
  },
  {
    "type": "library",
    "bom-ref": "pkg:npm/@hotwired/turbo@8.0.4",
    "group": "@hotwired",
    "name": "turbo",
    "version": "8.0.4",
    "purl": "pkg:npm/%40hotwired/turbo@8.0.4",
    "scope": "required",
    "description": "Hotwire Turbo Drive, loaded at runtime via CDN (unpkg.com). Not present in package-lock.json.",
    "licenses": [{ "license": { "id": "MIT" } }],
    "externalReferences": [
      { "type": "distribution", "url": "https://unpkg.com/@hotwired/turbo@8.0.4/dist/turbo.es2017-umd.js" },
      { "type": "website",      "url": "https://turbo.hotwired.dev" },
      { "type": "vcs",          "url": "https://github.com/hotwired/turbo" }
    ],
    "hashes": [
      { "alg": "SHA-256", "content": "5e60873390f4b4f2844113d59dddea85af45cc72352dc3a122ce1ecf60f1b6a5" },
      { "alg": "SHA-384", "content": "f25ef15f6348f85093ba6addc8093b12a9cc6c2baaf3c18c1efcac3c053918969824afb0255f44c71d22a62169f4b7f0" },
      { "alg": "SHA-512", "content": "57d6901c36def147ef3e65535e9a2a7cd0bed85bedf7f7987b0ef17d63f6e70df5f1f5e5377393bc9c6fbe7be94ce56b851f31f87e4bbb20a137dd77a01ddf3e" }
    ],
    "properties": [
      { "name": "cdx:npm:package_name",        "value": "@hotwired/turbo" },
      { "name": "picstudio:delivery_channel",  "value": "cdn" },
      { "name": "picstudio:cdn_provider",      "value": "unpkg" }
    ]
  }
]
PATCH_EOF

NEW_UUID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ROOT_REF="$(jq -r '.metadata.component."bom-ref"' "$OUT")"

echo "→ patching CDN-delivered components (Alpine + Turbo)..."
jq --slurpfile patch "$TMP/patch.json" \
   --arg uuid "urn:uuid:$NEW_UUID" \
   --arg ts "$NOW" \
   --arg rootRef "$ROOT_REF" '
  .components += $patch[0]
  | .dependencies = (
      .dependencies
      | map(
          if .ref == $rootRef
          then .dependsOn += [
            "pkg:npm/alpinejs@3.14.9",
            "pkg:npm/@alpinejs/collapse@3.14.9",
            "pkg:npm/@alpinejs/focus@3.14.9",
            "pkg:npm/@hotwired/turbo@8.0.4"
          ]
          else .
          end
        )
      + [
          { "ref": "pkg:npm/alpinejs@3.14.9",           "dependsOn": [] },
          { "ref": "pkg:npm/@alpinejs/collapse@3.14.9", "dependsOn": ["pkg:npm/alpinejs@3.14.9"] },
          { "ref": "pkg:npm/@alpinejs/focus@3.14.9",    "dependsOn": ["pkg:npm/alpinejs@3.14.9"] },
          { "ref": "pkg:npm/@hotwired/turbo@8.0.4",     "dependsOn": [] }
        ]
    )
  | .serialNumber = $uuid
  | .metadata.timestamp = $ts
  | .metadata.properties = ((.metadata.properties // []) + [
      { "name": "picstudio:cdn_patch_applied",    "value": $ts },
      { "name": "picstudio:cdn_patch_components", "value": "alpinejs@3.14.9, @alpinejs/collapse@3.14.9, @alpinejs/focus@3.14.9, @hotwired/turbo@8.0.4" },
      { "name": "picstudio:cdn_patch_reason",     "value": "Components delivered via jsdelivr/unpkg CDN per CLAUDE.md §5, not present in package-lock.json" }
    ])
' "$OUT" > "$TMP/patched.json"

mv "$TMP/patched.json" "$OUT"

# --- 3. Report --------------------------------------------------------------
TOTAL_COMP="$(jq '.components | length' "$OUT")"
TOTAL_DEPS="$(jq '.dependencies | length' "$OUT")"
echo "✔ SBOM generated: $OUT"
echo "  components:   $TOTAL_COMP"
echo "  dependencies: $TOTAL_DEPS"
echo "  spec:         CycloneDX $(jq -r '.specVersion' "$OUT")"
