# AGENTS.md — Pour Claude Code

Ce fichier indique aux agents Claude Code comment opérer ce cookbook quand il est invoqué dans un projet utilisateur.

---

## Quand un user te dit "bootstrap ce cookbook" ou "installe la stack Claude"

1. **Identifie le projet cible** (cwd ou path explicite)
2. **Lance** : `bash /Users/feugana1/Documents/dev/claude-cookbook/bootstrap-claude.sh <path>`
3. **Confirme à l'utilisateur** :
   - Liste les 8 agents installés dans `<path>/.claude/agents/`
   - Liste les 4 skills disponibles (`/feature`, `/pre-pr`, `/secu`, `/ux-review`)
   - Indique que `scan-secu.sh` est à la racine, exécutable
   - Mentionne le `CLAUDE.md` minimal à enrichir
4. **Avant d'écrire le 1er commit** : invoque le subagent `product-strategist` pour valider la première feature (couche 0 strategic gate).

---

## Quand un user te dit "audite mon repo avec scan-secu"

1. Vérifie présence : `ls scan-secu.sh` à la racine
2. Si absent : `cp /Users/feugana1/Documents/dev/claude-cookbook/scripts/scan-secu.sh .` puis `chmod +x scan-secu.sh`
3. Lance : `bash scan-secu.sh`
4. Parse l'output tier (T1 BLOCKER / T2 IMPORTANT / T3 ADVISORY) — résume les "Top risks open"
5. Propose fix pour chaque P0 (T1 FAIL) en premier

---

## Architecture du cookbook — 6 couches d'experts

Référence canonique : `docs/claude-config/experts.md` (492L).

```
Couche 0 — Strategic gate         : product-strategist (avant toute new feature)
Couche 1 — Architects             : back-architect, migration-reviewer
Couche 2 — Cross-cutting          : security-multitenant, data-access-reviewer
Couche 3 — Domain experts         : workflow-email (génériques — ajouter domain-specific dans le projet utilisateur)
Couche 4 — Linters fast           : edge-anti-patterns (haiku, scan grep)
Couche 5 — Final gate             : code-reviewer (avant git commit)
```

**Règle d'or** : un expert dit "REJECT" → tu corriges, tu ne contournes pas. Pas de complaisance.

---

## Quand un user te dit "ajoute un nouvel agent"

1. Lis `docs/claude-config/experts.md` §"R01-R17 roadmap"
2. Vérifie qu'aucun agent existant ne couvre déjà le besoin (anti-duplication)
3. Si nouveau : crée dans `.claude/agents/<name>.md` avec frontmatter `name/description/tools/model`
4. Description **active** ("Use PROACTIVELY when…", "Triggers when user says…") — pas "Specialized in…"
5. Ajoute au catalogue dans `docs/claude-config/experts.md`
6. **Si générique (cross-project)** : propose copie vers le cookbook (`cp .claude/agents/<name>.md /Users/feugana1/Documents/dev/claude-cookbook/.claude/agents/`)
7. **Si project-specific** : reste local au projet

---

## Quand un user te dit "applique une lesson learned"

1. Lis `docs/lessons.md` §3 et §4
2. Identifie la lesson pertinente
3. Modifie le code en conséquence
4. **Important** : ajoute le pattern à `docs/anti-patterns.md` si c'est un nouveau pattern découvert
5. **Si générique** : propose update du `docs/anti-patterns.md` du cookbook

---

## Anti-patterns du cookbook lui-même

🚫 **Ne PAS** :
- Réinventer un agent qui existe déjà (utilise `product-strategist` plutôt que créer "vision-validator")
- Ajouter de la cérémonie (semver, CHANGELOG.md, releases) — c'est un kit perso solo, pas un produit
- Mélanger code spécifique projet dans les agents génériques (mark TODO si Mix)
- Skipper le strategist couche 0 sur new features (CLAUDE.md §8 — règle absolue)
- Skipper le code-reviewer couche 5 avant commit (§17.3 — règle absolue)

✅ **Faire** :
- Toujours commencer par `feature` skill ou `product-strategist` agent
- Toujours finir par `pre-pr` skill ou `code-reviewer` agent
- Garder la discipline §17 Workflow Agentic (plan mode, sous-agents délèguent recherche, vérification avant clôture, boucle auto-amélioration)
- Enrichir `lessons.md` après chaque correction utilisateur

---

## Procédure pour onboarding agent sur projet nouveau

Quand tu démarres un projet **frais** avec ce cookbook :

1. `bash bootstrap-claude.sh .` (init)
2. Lis le `CLAUDE.md` minimal créé — c'est ton instruction-set
3. Lis `docs/lessons.md` §1 (Karpathy 4 disciplines)
4. Vérifie `.claude/agents/` — 8 agents génériques disponibles
5. Pour la première feature : invoque `product-strategist` avant tout code (`Agent` tool avec `subagent_type="product-strategist"`)
6. Après chaque commit non-trivial : invoque `code-reviewer`
7. Avant chaque push : lance `bash scan-secu.sh` + résume top risks

---

## Versioning

Pas de semver. Le cookbook évolue par commits granulaires sur son repo dédié. Pour figer une version dans un projet : `bootstrap-claude.sh` copie l'état actuel (pas de "lock file"). Si tu veux revenir à un état antérieur : `git checkout <sha>` dans le cookbook puis re-bootstrap.

---

## Pour enrichir le cookbook depuis un projet utilisateur

L'utilisateur travaille typiquement dans un projet (ex: PicStudio). Quand une amélioration générique émerge (nouveau pattern, lesson learned, agent générique) :

1. Implémente localement dans le projet
2. Une fois validé en prod, propose à l'utilisateur : "Cette amélioration est générique, je la copie vers le cookbook ?"
3. Si OK : `cp <fichier-local> /Users/feugana1/Documents/dev/claude-cookbook/<même-chemin>`
4. Commit dans le cookbook avec message explicite
5. Les autres projets de l'utilisateur récupèrent via `bootstrap-claude.sh . --update`

---

## Mémoire & contexte

Les memories Claude Code (`~/.claude/projects/.../memory/`) restent **par-projet** (pas de partage cross-project). Le cookbook fournit les **patterns**, pas les **observations spécifiques**.

Si un pattern de memory est universel (ex: `feedback_avoid_ceremony.md`), tu peux le copier dans `docs/lessons.md` §4 du cookbook après accord utilisateur.

---

## Discipline non-négociable

Si tu touches à ce cookbook (modify agents, scripts, docs), tu **dois** :
- Respecter la limite §14 : controllers ≤300L, services ≤400L, templates ≤800L (sinon split)
- Respecter `feedback_avoid_ceremony` (mémoire : pas de cérémonie)
- Préserver l'esprit "kit perso solo" (pas de README bilingue, pas de CI release pipeline)
- Valider via `bash scripts/scan-secu.sh` que le scan lui-même reste cohérent
