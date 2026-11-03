#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
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
