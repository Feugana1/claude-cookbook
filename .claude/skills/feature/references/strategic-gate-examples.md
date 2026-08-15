# `/feature` — Verdicts strategic gate (exemples calibration)

Référence chargée par `SKILL.md` step 2 — quand le `product-strategist` rend son verdict, comparer aux verdicts passés pour calibrer.

## GO différentiant

### "Anti-screenshot galerie privée"
- **Demande** : protéger les galeries privées partagées contre la capture d'écran
- **Verdict** : GO différentiant
- **Pourquoi** : Pixieset, Pic-Time, ShootProof ne le proposent pas. Angle "premium photo protection" cohérent avec PRODUCT.md.
- **Conditions de GO** : pas seulement détection, mais aussi watermark dynamique + bandeau visible + blocage clavier sur shortcut macOS. Cf `docs/features/anti-screenshot-galleries.md`.

### "Strategic gate / différenciation produit comme couche 0"
- **Demande** : ajouter un subagent qui challenge chaque nouvelle feature contre 13 concurrents
- **Verdict** : GO différentiant
- **Pourquoi** : aucune stack SaaS open-source ne fait cela. Renforce la discipline produit. Cf [`docs/claude-config/experts.md`](../../../docs/claude-config/experts.md) R12.

## REVOIR positionning

### "Module Tasks/CRM Kanban interne"
- **Demande** : intégrer un module Tasks Kanban dans MyProject (comme Honeybook)
- **Verdict** : REVOIR
- **Pourquoi** : Honeybook + Tave couvrent déjà ce marché en profondeur. Recoder un Kanban interne sans angle premium = "yet another CRM". Reformuler en : "Workflow visuel par client" attaché aux galeries (pas un Kanban générique).

## NO-GO trop générique

### "Système NPS interne post-livraison"
- **Demande** : afficher un NPS interne après livraison galerie pour mesurer satisfaction client photographe
- **Verdict** : NO-GO
- **Pourquoi** : le flow review existant pointe vers Google avis (preuve sociale + SEO photographe). NPS interne = donnée dormante sans actionabilité. Cf memory `feedback_no_internal_nps`.
- **Décision** : feature supprimée 2026-05-30 (S7-03).

### "Marketplace de presets Lightroom"
- **Demande** : permettre aux photographes de vendre/acheter des presets sur MyProject
- **Verdict** : NO-GO
- **Pourquoi** : marché saturé (Tonelist, FilterGrade), pas de pouvoir d'achat depuis MyProject, dilue le focus "expérience client". Cf PRODUCT.md "the photo leads".

## Pattern global des verdicts

- **GO** : différenciation claire vs ≥ 3 concurrents trackés + alignement PRODUCT.md "the photo leads"
- **REVOIR** : idée valide mais positionnement trop générique, reformulable
- **NO-GO** : feature commodity ou hors mission produit

Les verdicts passés sont ajoutés ici à chaque feature significative pour calibrer les futurs `product-strategist` runs.
