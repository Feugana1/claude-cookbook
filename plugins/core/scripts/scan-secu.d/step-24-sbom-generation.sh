#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 24. SBOM generation (CycloneDX 1.6 — front + back) ─────────────────────
# Genere reports/sbom.cdx.json couvrant tout npm + 4 composants CDN (Alpine + Turbo).
# Le SBOM est un artefact reproductible (gitignore reports/), genere a chaque scan.
# Failure = WARN, pas FAIL (la generation peut planter sur reseau lent sans bloquer un push).
step 24 "SBOM generation (CycloneDX 1.6)" 3 "Supply chain"
if skip_if_diff; then :; elif [ -x scripts/generate-sbom.sh ]; then
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
