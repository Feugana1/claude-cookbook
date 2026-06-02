# Prompt d'Audit UX — PicStudio Digital Curator

> Utiliser ce prompt pour auditer tout écran ou module de l'app.
> Appliquer les fixes P0 → P1 → Quick wins dans cet ordre.

---

## Contexte et objectif

Tu audites un écran ou un ensemble d'actions de **PicStudio** (AdonisJS 6 + Edge.js + Alpine.js + TailwindCSS). L'objectif est que chaque écran et chaque action respecte simultanément six axes :

1. **User-first** — l'utilisateur comprend immédiatement ce qu'il peut faire, sans friction
2. **PLG (Product-Led Growth)** — zero-friction, progressive disclosure, empty states actifs, inline settings
3. **Design System Digital Curator** — tonal layering, z-index scale, font-display/tracking, button gradients, rounded-2xl cards
4. **Pas de redondance** — zéro doublon visuel ou d'information, zéro action inutile
5. **Premium visuel** — tout doit convaincre par le soin et la finition
6. **Restraint cognitif** — luxe = moins ; masquer ce qui n'est pas utile *maintenant* à ce user dans ce contexte, sans perdre la pédagogie

---

## Axe 1 — User-first

**Questions à poser sur chaque écran :**
- Qu'est-ce que l'utilisateur veut faire en arrivant ici ? Est-ce immédiatement visible ?
- Y a-t-il des états vides ? Sont-ils actifs (CTA illustré) ou passifs (message statique) ?
- Les erreurs sont-elles expliquées avec une action corrective ?
- Les actions destructives ont-elles une confirmation inline (jamais `window.confirm()`) ?
- Les actions longues ont-elles un état loading + spinner + disabled button ?
- Les formulaires soumis une seule fois (pas de double-clic) ?

**Patterns actions :**

```html
<!-- Loading state obligatoire sur tout formulaire POST -->
<form x-data="{ submitting: false }" x-on:submit="submitting = true">
  <button :disabled="submitting" class="... disabled:opacity-40 disabled:cursor-not-allowed">
    <span x-show="!submitting">Label</span>
    <span x-show="submitting" x-cloak class="size-4 animate-spin rounded-full border-2 border-current border-t-transparent"></span>
  </button>
</form>

<!-- Confirmation inline 2-step (remplace window.confirm()) -->
<div x-data="{ confirming: false, submitting: false }">
  <button type="button" x-show="!confirming" x-on:click="confirming = true" class="...">
    Action dangereuse
  </button>
  <div x-show="confirming" x-cloak class="inline-flex items-center gap-2">
    <button type="button" x-on:click="confirming = false" class="... stone-100 ...">Annuler</button>
    <form x-on:submit="submitting = true">
      <button :disabled="submitting" class="... danger ... disabled:opacity-40">
        <span x-show="!submitting">Confirmer</span>
        <span x-show="submitting" x-cloak class="size-4 animate-spin ..."></span>
      </button>
    </form>
  </div>
</div>
```

---

## Axe 2 — PLG (Product-Led Growth)

**Checklist :**
- [ ] Empty states actifs : icône + titre + CTA principal (jamais juste un texte gris)
- [ ] Progressive disclosure : montrer les options avancées uniquement si pertinentes
- [ ] Upsell contextuel : si une feature nécessite un plan supérieur, l'indiquer là où l'utilisateur en a besoin
- [ ] Feedback immédiat : toute action donne un retour visuel (<500ms)
- [ ] Pas d'écran cul-de-sac : toute page d'erreur ou d'état terminal a un CTA de sortie
- [ ] Screens publics (expired, suspended, not_found) : CTA mailto vers le photographe si email disponible

**Pattern empty state actif :**
```html
<div class="text-center py-16">
  <div class="size-14 mx-auto mb-5 rounded-2xl bg-stone-100 dark:bg-stone-800 flex items-center justify-center">
    @svg('lucide:X', { class: 'size-7 text-stone-400' })
  </div>
  <h3 class="font-display font-bold text-stone-900 dark:text-white mb-2">Titre actionnable</h3>
  <p class="text-sm text-stone-500 dark:text-stone-400 mb-6 max-w-xs mx-auto">Description courte.</p>
  <a href="..." class="inline-flex items-center gap-2 rounded-xl bg-gradient-primary px-5 py-2.5 text-sm font-bold text-white shadow-lg shadow-primary/20">
    @svg('lucide:plus', { class: 'size-4' })
    CTA principal
  </a>
</div>
```

---

## Axe 3 — Design System Digital Curator

### Règle No-Line (CRITIQUE — clarifiée 2026-05-28)

La règle interdit les **lignes lourdes**, pas toutes les bordures. Différencier :

| Pattern | Statut | Cas d'usage |
|---|---|---|
| `border border-stone-200` ou `border-b border-stone-200` (heavy) | ❌ Interdit | Trop visuel, créé du chrome chapitré |
| `border border-stone-300+` | ❌ Interdit | Encore plus lourd |
| `border-b border-stone-100` (light) | ✅ **Acceptable** | Pattern canonique contacts/index : tables thead `<tr class="border-b border-stone-100">`, card section headers (intra-card) entre header et body |
| `divide-y divide-stone-100/80` | ✅ **Acceptable** | tbody tables, séparateurs subtils entre lignes |
| `divide-y divide-stone-200+` | ❌ Interdit | Trop lourd |
| `border-t border-stone-100` page-level separator (entre sections) | ❌ Interdit | Préférer tonal shift `bg-stone-50/40` ou spacing `mt-8` |
| `<div class="h-px bg-stone-100">` ou `<div class="w-px ...">` hardcoded | ❌ Interdit | Même règle, c'est une ligne déguisée en class différente |

**Pattern de référence — data list table** (cf `contacts/index.edge`) :
```html
<div class="overflow-hidden rounded-2xl bg-white shadow-sm dark:bg-stone-900">
  <table class="w-full text-left text-sm">
    <thead>
      <tr class="border-b border-stone-100 dark:border-stone-800"> ✅
        <th class="...">...</th>
      </tr>
    </thead>
    <tbody class="divide-y divide-stone-100/80 dark:divide-stone-800/60"> ✅
      <tr class="hover:bg-stone-50 dark:bg-stone-900 dark:hover:bg-stone-800/30">
```

**Pattern de référence — card section header** :
```html
<div class="rounded-2xl bg-white dark:bg-stone-900">
  <div class="border-b border-stone-100 dark:border-stone-800 px-5 py-4"> ✅ {{-- Header --}}
    <h2>...</h2>
  </div>
  <div class="p-5"> {{-- Body --}}
    ...
  </div>
</div>
```

**Préférer tonal shift / spacing UNIQUEMENT pour** :
- Séparer 2 sections de page (pas dans la même card)
- Headers de page (eyebrow + h1)
- Quand un border-b stone-200 existait (heavy = à supprimer)

**Quand changer un `border-b stone-200` existant** : passer à tonal shift `bg-stone-50/40` OU à `border-b stone-100` (selon contexte). Le tonal convient si parent est card-in-card hiérarchie. La light border convient si simple séparation header/body dans une card unique.

### Z-index scale obligatoire
| Usage | Valeur |
|-------|--------|
| sticky header/bar | `z-10` |
| dropdowns, tooltips | `z-20` |
| modal backdrops | `z-30` |
| modals, drawers | `z-40` |
| toasts, notifications | `z-50` |

Tout `z-[valeur-arbitraire]` (ex: `z-[999]`, `z-[200]`, `z-[60]`) est une violation.

### Typographie
- Titres : `font-display font-bold tracking-tight`
- Labels uppercase : `text-[10px] font-bold uppercase tracking-[0.15em] font-display`
- Pas de `tracking-widest`, pas de `tracking-[0.4em]` (trop agressif)

### Boutons
```html
<!-- Primaire -->
<button class="inline-flex items-center gap-2 rounded-xl bg-gradient-primary px-5 py-2.5 text-sm font-bold text-white shadow-lg shadow-primary/20 hover:brightness-110 transition-all">

<!-- Secondaire neutre -->
<button class="inline-flex items-center gap-2 rounded-xl bg-stone-100 px-4 py-2 text-sm font-medium text-stone-600 hover:bg-stone-200 dark:bg-stone-800 dark:text-stone-400 dark:hover:bg-stone-700 transition-colors">

<!-- Danger ghost -->
<button class="inline-flex items-center gap-2 rounded-xl border border-red-200 px-4 py-2 text-sm font-medium text-red-600 hover:bg-red-50 dark:border-red-900/40 dark:text-red-400 dark:hover:bg-red-950/30 transition-colors">
```

### Cards
```html
<div class="rounded-2xl bg-white dark:bg-stone-900 shadow-[0_8px_30px_rgba(0,0,0,0.04)] dark:shadow-none">
  <!-- Card header : tonal shift, pas de border -->
  <div class="bg-stone-50/50 dark:bg-stone-800/30 px-6 py-4 rounded-t-2xl">
    <h3 class="font-display font-semibold text-stone-900 dark:text-white">Titre</h3>
  </div>
  <div class="p-6">...</div>
</div>
```

### Anti-patterns critiques spécifiques aux vues Edge

| Anti-Pattern | Correct |
|-------------|---------|
| `@click` dans un fichier `@include`d | `x-on:click` |
| `window.confirm()` | Alpine 2-step inline |
| `alert()` | Inline error state (`x-text="errorMsg"`) |
| `@svg('lucide:X')` en milieu de ligne | `@svg` doit être premier non-whitespace de sa ligne |
| SVG inline hardcodé | `@svg('lucide:...')` |
| `z-[valeur-arbitraire]` | z-index scale z-10/20/30/40/50 |
| `border-b border-stone-200` comme séparateur | spacing ou tonal shift |
| `{{{ JSON.stringify() }}}` dans `x-data` | `<script type="application/json">` |

---

## Axe 4 — Pas de redondance

**Checklist :**
- [ ] Pas d'information affichée deux fois sur le même écran
- [ ] Pas deux chemins d'action qui font la même chose
- [ ] Pas de bouton "Annuler" et croix de fermeture qui ont exactement le même comportement sans raison
- [ ] Pas de label + placeholder qui disent la même chose
- [ ] Pas de titre de page + breadcrumb qui répètent la même info

---

## Axe 5 — Premium visuel

**Checklist :**
- [ ] Animations d'entrée fluides (stagger si liste, pas sur éléments isolés)
- [ ] Hover states sur tous les éléments interactifs
- [ ] Focus visible accessible (`focus-visible:ring-2 focus-visible:ring-primary/40`)
- [ ] Images : `object-cover` + `transition-transform duration-700` au hover
- [ ] Icônes cohérentes (Lucide uniquement, via `@svg`)
- [ ] Spacing généreux (padding intérieur cards minimum `p-5`, sections minimum `py-12`)
- [ ] Dark mode complet (chaque classe de couleur a son pendant `dark:`)

---

## Axe 6 — Restraint cognitif (luxe = moins, contextuel)

> **Principe directeur** : une interface luxe n'est pas vide, elle est **focalisée**. Le user *vit* le parcours principal ; le reste est masqué jusqu'à ce qu'il en ait besoin. Pas de mur d'options, pas de réglages techniques étalés, pas de cartes sans utilité immédiate.

**Trois questions à se poser sur chaque écran :**

1. **Quel est le parcours primaire ?** Un seul, identifiable en moins de 2 secondes. Tout le reste est secondaire.
2. **Qu'est-ce qui n'est PAS utile MAINTENANT à ce user dans ce contexte ?** À masquer (pas supprimer — juste pas exposé d'emblée).
3. **Comment l'interface s'adapte-t-elle au contexte du user ?** Pays, plan, état du parcours → l'écran change pour rester pertinent.

**Patterns d'application :**

- **Progressive disclosure par groupe** — quand 3+ cards portent du config/réglage secondaire, les grouper sous un accordion `<section x-data="{ open: false }">` titre "Réglages avancés". Une seule chose visible par défaut, expansion à la demande.
- **Contextual collapse** — un bloc non-applicable au user (ex: provider de paiement non supporté dans son pays, feature non incluse dans son plan) → version COMPACTE inline (1 ligne + pill statut), pas une carte vide ou désactivée à plein écran. Garder la pédagogie via un lien "Pourquoi ?" qui expand.
- **Adaptation au profil** — si l'écran charge des données qui dépendent du `company.country` / `user.plan` / `subscription.status`, l'ordre + la visibilité des sections doit refléter ce contexte (le user CM voit NotchPay en premier ; le user EU voit Stripe en premier).
- **Tonal hierarchy intra-card** — quand un parent contient des enfants (ex: accordion → sub-cards), les enfants quittent `bg-white` pour `bg-stone-50/50` (dark : `bg-stone-800/50`). Pas de double card chrome empilé.
- **Une statistique > N statistiques** — si un module a 6 metrics, en mettre 1 en hero, les 5 autres derrière "Voir détails". Sauf si tous sont d'égale importance dans le golden path.

**Anti-patterns (P0 — bloquer le merge) :**

| Anti-pattern | Pourquoi c'est cassé | Fix |
|--------------|---------------------|-----|
| Page > 5 cards/sections visibles d'un coup sans hiérarchie | Le user scrolle pour comprendre l'utile vs l'avancé → friction | Grouper le secondaire sous accordion |
| Carte avec status `disabled` / `not_configured` qui prend autant de place que les cartes actives | Le user pense que c'est cassé ou doit agir dessus | Compact 1-line ou masquer + lien "Pourquoi ?" |
| Réglages techniques (clés API, webhooks, IDs) visibles dans l'interface user | Aucune valeur pour le photographe, charge cognitive + risque erreur | Backend-only, jamais exposés |
| Même information répétée 2x sur l'écran (label + placeholder ; titre + breadcrumb identique) | Bruit visuel | Choisir un seul endroit |
| Carte de "metrics dashboard" sur un écran de config | Mélange contexte action + contexte analyse | Metrics → page Analytics dédiée |

**Test de lecture (60 secondes) :**

Un user qui n'a jamais vu l'écran doit pouvoir répondre en 60 secondes :
1. "Qu'est-ce que je peux faire ici en priorité ?" (la primary action)
2. "Quelle est mon état actuel ?" (statut visible, sans interpréter)
3. "Où je vais après ?" (next step évident)

Si une de ces 3 réponses demande plus de 60s, il y a un échec d'Axe 6.

---

## Format de sortie de l'audit

```
### Audit — [Nom du module]

**P0 (bloquer)** :
- [fichier:ligne] — description du problème → solution

**P1 (avant merge)** :
- [fichier:ligne] — description → solution

**Quick wins** :
- [fichier:ligne] — description → solution

**Déjà correct** :
- Liste ce qui est déjà bien (renforce les patterns à répliquer)
```

---

## Ordre d'audit recommandé

État au 2026-05-28. Mettre à jour cette section à chaque nouveau audit ✅/⚠️.

**Public (client-facing)** :
1. ✅ Galerie publique (`resources/views/pages/galleries/public/`)
2. ✅ Portail client (`resources/views/pages/portal/index.edge`) — trackings + chips + font-weight charte 2026-05-28
3. ✅ Booking public (`resources/views/pages/bookings/public/_step_*`) — sweep inputs no-line + reschedule + availability
4. ✅ Transfert public (`resources/views/pages/transfers/public/`) — lazy cover picker + OG fallback

**Admin (workspace photographe)** :
5. Dashboard (`resources/views/pages/dashboard/`) — non audité formellement
6. ✅ Admin galeries (`resources/views/pages/galleries/edit.edge`) — inputs filled + loading state submit
7. ✅ Contacts (`resources/views/pages/contacts/show.edge` + `_header.edge`) — pattern devis (Quick Actions + Edit + Kebab) + accordion finances + redondance Personal info supprimée
8. Documents :
   - ✅ `quotes/index.edge`, `quotes/show.edge` — shadow alias + charte buttons
   - ✅ `invoices/index.edge` — shadow alias
   - ✅ `contracts/show.edge` — status select no-line
   - ✅ `credit_notes/index.edge` — hover bug fix
   - ⚠️ Reste à auditer : `quotes/edit.edge`, `invoices/show.edge`, `contracts/index.edge`, `contracts/edit.edge`
9. ✅ Services (`pages/services/show.edge` + 7 partials + `_actions.edge`, `_board_card.edge`, `_filters.edge`, `index.edge`, `edit.edge`, `board.edge`, `types/index.edge`) — pattern devis Quick Actions + sweep window.confirm + safe status change + shadow alias
10. ✅ Calendrier/Events (`pages/events/`) — déjà clean (audit antérieur)
11. ✅ Transferts admin (`resources/views/pages/transfers/`) — refactor antérieur

**Paramètres (sub-pages settings)** :
12. ✅ `settings/team.edge` — safe role change + tables canonique
13. ✅ `settings/fiscal.edge` — pagination component + sections borders
14. ✅ `settings/subscriptions.edge` + `_sub_card` — FCFA + cards modernes
15. ✅ `settings/fields.edge` — inputs filled
16. ✅ `settings/emails.edge` — tabs + sections borders
17. ✅ `settings/payments.edge` (refactor antérieur)
18. ✅ `settings/white_mark.edge` (refactor antérieur)
19. ✅ `settings/google_drive.edge` (refactor antérieur)
20. ✅ `settings/catalog.edge` (refactor antérieur)
21. ⚠️ Reste à auditer : `settings/security.edge`, `settings/numbering.edge`, `settings/receivables.edge`, `settings/reminders.edge`, `settings/notifications.edge`, `settings/lightroom.edge`, `settings/google_calendar.edge`, `settings/integrations.edge`, `settings/accounting.edge`, `settings/einvoice.edge`

**Landing public (site marketing)** :
22. ✅ `landing/index.edge` — fix overlap nav 1024-1280px (flexbox 3 cols)
23. ✅ `landing/_nav.edge` — pattern déjà appliqué (commit antérieur)

**Système (transverse)** :
24. ✅ Sidebar admin (`partials/sidebar.edge`) — fix toggle clipping + dropdown profile collapsed lisible
25. ✅ Data list tables sweep (8 files) — canonical contacts pattern
26. ✅ Charte modales (`_send_with_preview.edge`) — source de vérité unique

**Convention de tracking** :
- ✅ = page auditée + refactor P0+P1 appliqué + déjà dans `project_ux_debt.md` section refactorée
- ⚠️ = identifiée comme à auditer (grep révèle violations, mais audit formel non lancé)
- Sans marker = pas encore évalué

---

## Références

- Design System complet : [`docs/design-system.md`](design-system.md)
- Anti-patterns : [`docs/anti-patterns.md`](anti-patterns.md)
- Règles Alpine+Turbo : CLAUDE.md §6
