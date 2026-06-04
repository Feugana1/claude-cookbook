# Lionel — Claude Code Cookbook

Stack Claude Code réutilisable extraite du projet PicStudio (2025-2026). Sub-agents, hooks, scripts qualité, anti-patterns, templates — pensés pour être adoptés sur n'importe quel projet AdonisJS / Node / TypeScript.

**Statut** : v0.1 extraction brute (Phase 1 du plan d'externalisation). Dépollution Mix (Phase 2) différée au prochain bootstrap d'un nouveau projet.

---

## Qu'est-ce qu'il y a dedans

```
.claude/
├── agents/          8 sub-agents génériques (strategist, code-reviewer, architects, security, workflow-email…)
├── skills/          4 slash commands (/feature, /pre-pr, /secu, /ux-review)
└── hooks/           2 hooks shell (dispatch-expert auto-routing + precommit-check rappel reviewer)
scripts/
├── scan-secu.sh     orchestrator ~150L (helpers + counters + verdict)
├── scan-secu.d/     33+ stateless step modules sourced in order
│                    Drop a `step-NN-<slug>.sh` → TOTAL auto-bumps
├── check-file-sizes.js  ratchet CI tailles fichiers (controllers/services/templates)
└── generate-sbom.sh CycloneDX 1.6 SBOM front + back
docs/
├── lessons.md            Karpathy 4 disciplines + leçons accumulées
├── anti-patterns.md      Catalogue exhaustif anti-patterns Edge/Alpine/AdonisJS
├── feature-plan-template.md  Template unifié spec + plan + completeness (~200L max)
├── ux-audit-prompt.md    6 axes audit UX (User-first, PLG, DS, restraint cognitif…)
└── claude-config/        Catalogue agents, setup cross-poste, intégration superpowers
```

Total : **29 fichiers, ~5000 lignes** de méthodologie distillée sur 6 mois de prod PicStudio.

---

## Pour bootstrap un NOUVEAU projet

Depuis le dossier de ton nouveau projet :

```bash
bash /Users/feugana1/Documents/dev/claude-cookbook/bootstrap-claude.sh .
```

Le script copie `.claude/`, `scripts/`, `docs/` dans le projet courant + crée `.claude/CLAUDE.md` minimal à enrichir.

## Pour mettre à jour les fichiers du cookbook dans un projet existant

```bash
bash /Users/feugana1/Documents/dev/claude-cookbook/bootstrap-claude.sh . --update
```

Mode update : écrase uniquement les fichiers du cookbook, ne touche pas aux fichiers spécifiques projet (`CLAUDE.md`, agents custom, hooks override, etc.).

---

## Source de vérité : où enrichir

**Modèle a — recommandé court terme** : enrichir dans le projet actif (ex: PicStudio), exporter périodiquement vers le cookbook via copie sélective. Les patterns émergent en prod, le cookbook fige les bonnes pratiques.

**Modèle b — long terme** : enrichir directement le cookbook, importer dans projets via bootstrap `--update`. Plus rigoureux mais demande discipline de sync.

---

## Assets PicStudio-only NON inclus (restent dans PicStudio)

- `nf525-accounting` (légal FR)
- `shop-marketplace`, `subscription-quota` (business logic)
- `front-curator` (design system Digital Curator)
- `public-experience` (routes PicStudio)
- CLAUDE.md root (stack-specific 17 sections)
- `docs/business-rules.md`, `docs/design-system.md`, `docs/competitive-benchmark/*`

---

## Pour les agents Claude Code

→ Lire [AGENTS.md](AGENTS.md) pour comprendre comment opérer ce cookbook.
