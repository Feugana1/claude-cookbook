# Changelog

## 0.2.1 — 2026-11-26

### Fixed
- scan-secu step 8 (SSRF) : ne ignore plus les lignes contenant `test`/`comment` dans le chemin ; seuls les commentaires de code et `.test.`/`.spec.` sont exclus. Fallbacks `env.get(`/`process.env` et marqueur `canonical-skip:ssrf` tolérés.
- scan-secu step 31 (webhooks) et step 9 (Trivy) : `grep -c ... || echo "0"` produisait `"0\n0"` et masquait la détection.

### Added
- `scripts/test-scan-secu-steps.sh` : tests à fixtures pour ~25 steps (core, adonisjs, expo).
- `scripts/test-precommit-hook.sh` : 9 cas pour le hook precommit (typecheck, ratchet, commandes ignorées).
- CI : shellcheck `--severity=warning`, markdownlint, test du hook precommit.

### Changed
- `.markdownlint.json` assoupli (règles purement stylistiques désactivées) ; titres MD001/MD058 corrigés.

## 0.2.0
- Packs core, adonisjs, expo ; bootstrap-claude.sh ; sous-agents Sonnet par défaut.
