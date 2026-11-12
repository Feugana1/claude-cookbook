# Design system — contrat UI du projet

> **Destinataire** : agent `frontend` (audit UI/UX) et toute session qui touche une vue. Copier en `docs/design-system.md`, remplir en 20 min, maintenir à chaque composant ajouté.
> **Format** : des valeurs et des noms, pas de prose. Une règle non écrite ici n'existe pas pour l'agent.
> **Spirit** : le principe central produit vit dans `PRODUCT.md` ; ce doc dit comment il se voit à l'écran.

---

## 1. Tokens

| Famille | Valeurs (remplacer) | Règle |
| --- | --- | --- |
| Couleurs sémantiques | `surface`, `surface-raised`, `text`, `text-muted`, `primary`, `danger`, `success`, `warning` | jamais une couleur brute (`#…`, `stone-200`) dans une vue : toujours un token |
| Espacement | échelle 4 / 8 / 12 / 16 / 24 / 32 / 48 | pas de valeur hors échelle |
| Typo | police display, police texte, tailles `xs sm base lg xl 2xl`, graisses 400 / 500 / 600 | 1 police display max |
| Rayons | `sm md lg full` | une seule valeur par niveau de composant (carte = `lg`, bouton = `md`…) |
| Ombres | `sm md` | ombre = élévation, jamais décoration |
| Mode sombre | tokens redéfinis sous `[data-theme=dark]` ou `prefers-color-scheme` | tout écran vérifié dans les deux modes |

## 2. Composants canoniques

Un composant = un nom, un emplacement, zéro variante one-off. Lister les existants :

| Composant | Fichier | Variantes autorisées |
| --- | --- | --- |
| Bouton | `<path>` | primary / secondary / ghost / danger ; tailles sm / md |
| Carte | `<path>` | default / raised |
| Champ de formulaire | `<path>` | text / select / textarea / toggle ; état erreur intégré |
| Modale / sheet | `<path>` | confirm / form |
| Empty state | `<path>` | illustration + CTA (jamais un message seul) |
| Toast / alerte | `<path>` | info / success / danger |

Besoin d'une variante absente → l'ajouter au composant canonique, pas à la vue.

## 3. États obligatoires

Toute action ou écran couvre : **chargement** (bouton disabled + spinner), **erreur** (message actionnable, champ en cause), **vide** (empty state actif), **succès** (confirmation inline).
Actions destructives : confirmation inline, jamais `window.confirm()`.

## 4. Restraint et densité

- Test des 60 s : l'utilisateur comprend quoi faire en arrivant, sans lire.
- Un écran = une action principale visible ; le reste en progressive disclosure.
- Pas de doublon d'information ni d'action sur un même écran.
- Densité max par écran (adapter) : `<N>` sections visibles, `<N>` boutons primaires = 1.

## 5. Accessibilité (non négociable)

WCAG 2.1 AA : contraste ≥ 4,5:1 texte / 3:1 UI, focus visible, navigation clavier, `aria-label` sur boutons icône, labels et erreurs liés aux champs, cibles tactiles ≥ 44 × 44.

## 6. Anti-patterns visuels (grepables → candidats hook)

| Interdit | Remplacer par |
| --- | --- |
| couleur brute dans une vue | token §1 |
| `window.confirm()` / `alert()` | confirmation inline |
| style inline `style="…"` | classe ou composant |
| composant copié-collé avec 1 variante | variante du canonique §2 |
| `<ajouter les patterns du projet>` | |

## 7. Références

- `PRODUCT.md` — principe central, personas
- Charte visuelle / maquettes : `<lien ou chemin>`
- Librairie UI utilisée : `<nom + version>`
