---
name: ux-review
description: Audit a PicStudio page (Edge template + partials) against docs/ux-audit-prompt.md and CLAUDE.md §17.6 UI density rules. Outputs P0/P1/Quick wins in the prescribed format. Use when the user asks /ux-review, requests a UX audit, or before adding a feature to a config screen. Triggers proactively when user says a page feels "chargé", "dense", "overloaded", "ne respire pas", or references PRODUCT.md spirit.
tools: Read, Glob, Grep, Bash
---

# UX Review — PicStudio

Audit a page against the 6 axes from `docs/ux-audit-prompt.md` + UI density gates from `docs/anti-patterns.md` + PRODUCT.md spirit. Output: actionable P0/P1/Quick wins.

## When to invoke

- User types `/ux-review <page>` or `/ux-review pages/portfolio/index.edge`
- User says a page feels "chargé", "dense", "overloaded", "ne respire pas", "trop d'options visibles"
- User references PRODUCT.md, `digital curator`, "the photo leads"
- **Proactive trigger**: BEFORE adding a new section/setting to an existing config screen — run an audit first to confirm the screen can absorb a new section without breaking Axe 6 cognitive restraint.

## Inputs

- A page path (e.g. `pages/portfolio/index.edge`) OR a route (e.g. `/portfolio` → resolve via `start/routes/*` to controller + view)
- Optional: a focus area ("preview", "header", "sections", "mobile") to bias the audit

## Procedure

### 1. Load context (parallel reads)

```bash
# The page itself + all included partials
grep -E "@include\\(.*\\)" <page> | sed -E "s/.*@include\\('([^']+)'.*/\\1/"

# Lang keys referenced
grep -oE "t\\('[a-zA-Z._]+'\\)" <page>

# Controller + view props
# Find via: grep -rn "view.render\\('<page-without-ext>" app/controllers
```

Read in parallel:
- `docs/ux-audit-prompt.md` (the 6 axes)
- `docs/design-system.md` (button/card/typography patterns)
- `docs/anti-patterns.md` (especially "UI Density" + "Design System" sections)
- `PRODUCT.md` (brand personality + design principles + anti-references)
- `CLAUDE.md` §7 (design system) + §13 (anti-patterns) + §17 (workflow)
- The page + all its partials + the controller that renders it

### 2. Apply the 6 axes

For each axis from `docs/ux-audit-prompt.md`, list violations with file:line:

1. **User-first** — primary action obvious in 2s ? loading states ? confirmations inline ?
2. **PLG** — empty states actifs ? progressive disclosure ? feedback < 500ms ?
3. **Design System** — no-line rule ? z-index scale ? typography ? buttons ? cards ?
4. **No redundancy** — same info displayed 2x ? duplicate CTAs ?
5. **Premium visuel** — hover/focus states ? spacing généreux ? dark mode ?
6. **Restraint cognitif** — max 4 sections visibles d'un coup ? mur d'options ? chrome décoratif ?

### 3. Apply UI density gates (CLAUDE.md §13b / anti-patterns "UI Density")

Hard rules — any of these is a P0:

- **Max 4 sections visibles d'un coup** sur un écran de config. Au-delà → accordion/tabs/progressive disclosure.
- **0 mock chrome** dans une preview live (browser frame, fake URL bar, fake dock, etc.)
- **0 numérotation chapitrée** `01 / 02 / ..` dans les section headers.
- **Max 2 niveaux** de toggles imbriqués dans une même card.
- **Header de page**: max 1 ligne. Pas de titre + sous-titre dupliquant la sidebar.
- **0 badges décoratifs** sans utilité (pulsing dot "LIVE", glassmorphism gratuit, etc.)
- **0 icon square 7×7** systématique à gauche de chaque section header — c'est du chrome chapitré.

### 4. Test de lecture 60s

Un user qui voit la page pour la première fois doit pouvoir répondre en 60s :
1. "Qu'est-ce que je peux faire ici en priorité ?"
2. "Quel est mon état actuel ?"
3. "Où je vais après ?"

Si une réponse demande > 60s → échec Axe 6, classer en P0.

### 5. Output format (strict)

```
### Audit — [Nom du module / route]

## Diagnostic global

| Mesure | Actuel | Cible |
|---|---|---|
| Sections visibles au load | X | ≤ 4 |
| Champs/toggles d'un coup | X | ≤ 8 |
| Chrome décoratif | détails | 0 |
| ... | ... | ... |

## P0 — bloquer (P0 = violation PRODUCT.md / UI density gate)
- `file:line` — description → solution concrète

## P1 — avant merge
- `file:line` — description → solution

## Quick wins
- `file:line` — description → solution

## Déjà correct
- Liste ce qui est aligné (renforce les patterns à répliquer)
```

### 6. After-audit: update memory

If the audit reveals new patterns or pages at risk, **update memory** `project_ux_debt.md`:
- Add the page to the watch list with its audit date + outstanding items
- If the page was refactored, mark it ✅ resolved with the resolution date

## Anti-patterns to flag aggressively

| Symptom | Likely violation | Severity |
|---|---|---|
| Preview wrapped in a `<div>` with `rounded-2xl shadow` + a "dot dot dot" header | Browser chrome mock | P0 |
| `<h1>` + `<p>` description right under it | Header duplique le titre de la sidebar | P1 |
| Section header with `inline-flex size-7 ... bg-stone-100` icon square + `01 / LABEL` | Chrome chapitré | P0 |
| 4+ `<section>` ou `<div class="space-y-X">` direct children of a panel | Mur d'options | P0 |
| `animate-pulse` on a dot that's always visible | Décoratif sans info | P0 |
| `<button>` with 5+ inline preset shortcuts (focal, color, etc.) | Pas premium, drop most | P1 |
| Floating "Live preview" badge bottom-right | Décoratif | P0 |

## Reminder

This skill should NOT write code. It outputs an audit. The user invokes the refactor as a follow-up after reading the audit. Confirm before writing.
