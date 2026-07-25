# Copy to .husky/pre-commit (chmod +x) after `npm i -D husky && npx husky init`.
#
# Pre-commit — scan-secu delta mode + file-size ratchet.
# - scan-secu --diff (SECU_DIFF_STAGED=1) : scoped à git diff --cached, ~3s
#   couvre lint delta + patterns sécu/edge/alpine sur fichiers stagés
# - check-file-sizes : ratchet baseline (CLAUDE.md §14)
# Full scan (Trivy/npm audit/SBOM/build) → pre-push manuel : `bash scan-secu.sh`
# Full scan CI → cron hebdo `.github/workflows/scan-secu-weekly.yml`
SECU_DIFF_STAGED=1 bash scan-secu.sh --diff || exit 1
node scripts/check-file-sizes.js || exit 1
