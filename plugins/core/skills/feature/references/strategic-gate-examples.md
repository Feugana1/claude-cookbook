# `/feature` — Verdicts strategic gate (exemples génériques calibration)

Référence chargée par `SKILL.md` step 2 — quand le `product-strategist` rend son verdict, comparer aux verdicts passés pour calibrer.

Les exemples ci-dessous sont **génériques** (abstraits). Chaque projet doit tenir sa propre trace des verdicts passés dans `docs/features/<nom>.md` §Décision ou dans `docs/dev-changelog.md`.

## GO différentiant (patterns)

### Pattern "Angle sécurité premium sur commodity"
- **Contexte** : la feature est standard sur le marché, mais aucun concurrent tracké ne l'aborde avec l'angle sécurité/premium visé
- **Verdict** : GO différentiant
- **Pourquoi** : couvre un gap réel + cohérent avec principe central produit
- **Conditions de GO typiques** : implémentation qui incarne l'angle (ex: watermark dynamique, blocage clavier, audit trail), pas juste checkbox marketing

### Pattern "Nouveau primitif dans un espace mûr"
- **Contexte** : ajouter une primitive méthodologique (skill, agent, workflow) qui n'existe nulle part dans l'écosystème comparable
- **Verdict** : GO différentiant
- **Pourquoi** : renforce une discipline produit unique, non copiable rapidement

## REVOIR positionning (patterns)

### Pattern "Copie fonctionnelle d'un concurrent mature"
- **Contexte** : la feature demandée existe déjà en profondeur chez ≥ 2 concurrents trackés, sans angle différenciant clair
- **Verdict** : REVOIR
- **Pourquoi** : recoder une commodity = "yet another <catégorie>". Reformuler avec un axe premium projet-specific (ex: attacher la feature à un workflow différenciant existant, la scope-down à un use-case précis)

### Pattern "Feature générique mais implémentation qui pourrait être premium"
- **Contexte** : la feature est standard mais l'exécution pourrait devenir signature
- **Verdict** : REVOIR
- **Pourquoi** : validation possible si le brief est reformulé pour porter l'exécution différenciante

## NO-GO trop générique (patterns)

### Pattern "Donnée dormante sans actionabilité"
- **Contexte** : feature qui collecte une métrique interne (NPS, satisfaction, sondage) sans workflow d'action clair
- **Verdict** : NO-GO
- **Pourquoi** : dette produit — collecter sans actionner. Si un flow externe existe déjà (ex: avis Google, review publique), pointer vers lui.

### Pattern "Marché saturé + hors mission"
- **Contexte** : entrer dans un marché déjà couvert par des acteurs spécialisés, sans avantage distributionnel/produit
- **Verdict** : NO-GO
- **Pourquoi** : dilue le focus produit, coût opportunité élevé

### Pattern "Anti-référence violée"
- **Contexte** : la feature viole explicitement une anti-référence documentée dans `PRODUCT.md` (ex: transforme le produit en tableur, dashboard SaaS générique, complexité pour experts uniquement)
- **Verdict** : NO-GO
- **Pourquoi** : cohérence produit — les anti-références existent pour être respectées

## Pattern global des verdicts

- **GO** : différenciation claire vs ≥ 2-3 concurrents trackés + alignement principe central produit + simplification
- **REVOIR** : idée valide mais positionnement trop générique, reformulable en 1-3 alternatives
- **NO-GO** : feature commodity, hors mission produit, ou viole une anti-référence

Les verdicts passés du projet doivent être ajoutés au fur et à mesure dans `docs/features/<nom>.md` §Décision (ou changelog) pour calibrer les futurs `product-strategist` runs.
