#!/usr/bin/env bash
# ============================================================================
# bootstrap-claude.sh — installe le cookbook (core + pack de stack) dans un projet
#
# Usage :
#   bash bootstrap-claude.sh <projet> [--stack=<none|pack>] [--update] [--dry-run] [--force] [--with-git-tooling]
#
#   --stack=none     rôles génériques seuls (défaut hors TTY)
#   --stack=<pack>   core + pack ; un pack = dossier plugins/<pack>/ avec un pack.conf
#   --update         re-synchronise un projet déjà installé
#   --dry-run        affiche ce qui changerait, n'écrit rien
#   --force          écrase aussi les fichiers gérés adaptés par le projet (sauvegardés)
#   --with-git-tooling   installe aussi commitlint.config.js, lefthook.yml, .markdownlint.json
#
# Règles d'écrasement :
#   - fichiers gérés (agents, skills, hooks, scripts, docs de référence) : mis à jour
#     seulement s'ils sont restés tels que le cookbook les a installés. L'empreinte de
#     chaque fichier installé est notée dans .claude/.cookbook-manifest (à commiter).
#     Un fichier adapté par le projet, ou présent sans empreinte (projet antérieur au
#     manifeste), est conservé et signalé ; --force l'écrase. Toute version remplacée
#     est sauvegardée dans .claude/.cookbook-backup/<horodatage>/
#   - fichiers du projet (CLAUDE.md, .claude/settings.json, .mcp.json, docs/lessons.md,
#     docs/anti-patterns.md, docs du pack) : JAMAIS écrasés s'ils existent
#   - fichiers retirés du cookbook (plugins/core/retired.txt) et fichiers d'un autre
#     pack : sauvegardés puis supprimés, sauf s'ils ont été adaptés par le projet
#   - scripts/scan-secu.d/ n'est installé que si le scan-secu.sh du projet le charge
# ============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

COOKBOOK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE="$COOKBOOK_ROOT/plugins/core"

# ── Packs disponibles (= plugins/*/pack.conf) ───────────────────────────────
PACKS=()
for c in "$COOKBOOK_ROOT"/plugins/*/pack.conf; do
  [ -f "$c" ] && PACKS+=("$(basename "$(dirname "$c")")")
done
PACK_LIST="none${PACKS[0]:+|$(IFS='|'; echo "${PACKS[*]}")}"

usage() {
  echo -e "${RED}Usage: bash bootstrap-claude.sh <projet> [--stack=${PACK_LIST}] [--update] [--dry-run] [--force] [--with-git-tooling]${NC}"
  exit 1
}

[ $# -ge 1 ] || usage
TARGET_ARG="$1"; shift
UPDATE_MODE=false; DRY=false; FORCE=false; STACK=""; GIT_TOOLING=false
for arg in "$@"; do
  case "$arg" in
    --update) UPDATE_MODE=true ;;
    --dry-run) DRY=true ;;
    --force) FORCE=true ;;
    --stack=*) STACK="${arg#--stack=}" ;;
    --with-git-tooling) GIT_TOOLING=true ;;
    *) echo -e "${YELLOW}Argument inconnu ignoré : $arg${NC}" ;;
  esac
done

[ -d "$TARGET_ARG" ] || { echo -e "${RED}Dossier cible introuvable : $TARGET_ARG${NC}"; exit 1; }
TARGET="$(cd "$TARGET_ARG" && pwd)"

# ── Choix de la stack ───────────────────────────────────────────────────────
if [ -z "$STACK" ]; then
  if [ -t 0 ] && [ -t 1 ]; then
    echo -e "\n${BOLD}Choisir la stack :${NC}"
    echo "  0) none — rôles génériques (cross-stack)"
    i=1
    for p in "${PACKS[@]:-}"; do
      [ -n "$p" ] || continue
      desc=$(grep -E '^DESCRIPTION=' "$COOKBOOK_ROOT/plugins/$p/pack.conf" | head -1 | sed 's/^DESCRIPTION=//; s/"//g')
      echo "  $i) $p — ${desc}"
      i=$((i+1))
    done
    read -r -p "Choix [0] : " choice
    choice="${choice:-0}"
    if [ "$choice" = "0" ] || [ "$choice" = "none" ]; then STACK="none"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#PACKS[@]}" ]; then STACK="${PACKS[$((choice-1))]}"
    else STACK="$choice"; fi
  else
    STACK="none"
  fi
fi

PACK=""; REPLACES=""
if [ "$STACK" != "none" ]; then
  [ -f "$COOKBOOK_ROOT/plugins/$STACK/pack.conf" ] || { echo -e "${RED}Stack invalide : $STACK (attendu : ${PACK_LIST})${NC}"; exit 1; }
  PACK="$COOKBOOK_ROOT/plugins/$STACK"
  # shellcheck disable=SC1090
  source "$PACK/pack.conf"
fi

echo -e "${BOLD}══ Claude Cookbook → bootstrap ══${NC}"
echo -e "  Source : ${BLUE}${COOKBOOK_ROOT}${NC}"
echo -e "  Cible  : ${BLUE}${TARGET}${NC}"
echo -e "  Mode   : ${YELLOW}$([ "$UPDATE_MODE" = true ] && echo UPDATE || echo INIT)$([ "$DRY" = true ] && echo ' · DRY-RUN (aucune écriture)')${NC}"
echo -e "  Stack  : ${YELLOW}${STACK}${NC}"
echo ""

# ── Primitives d'installation ───────────────────────────────────────────────
N_ADDED=0; N_UPDATED=0; N_SAME=0; N_KEPT=0; N_RETIRED=0; N_CUSTOM=0
KEPT_DIFF=()
CUSTOM_KEPT=()
BACKUP_DIR=""

rel_of() { echo "${1#"$TARGET"/}"; }

# ── Manifeste : empreinte de chaque fichier tel que le cookbook l'a écrit ───
# Format : "<chemin relatif>\t<sha256>". Sert à distinguer une copie cookbook
# intacte (mise à jour sans risque) d'un fichier adapté par le projet (conservé).
MANIFEST="$TARGET/.claude/.cookbook-manifest"
MANIFEST_NEW="$(mktemp)"
trap 'rm -f "$MANIFEST_NEW"' EXIT

if command -v sha256sum >/dev/null 2>&1; then
  sha_of() { sha256sum "$1" | cut -d' ' -f1; }
else
  sha_of() { shasum -a 256 "$1" | cut -d' ' -f1; }
fi

manifest_sha() { # rel → empreinte notée à la dernière installation (vide si inconnue)
  [ -f "$MANIFEST" ] || return 0
  awk -F'\t' -v r="$1" '$1 == r { print $2; exit }' "$MANIFEST"
}

record() { printf '%s\t%s\n' "$1" "$2" >> "$MANIFEST_NEW"; } # rel sha

# Le fichier cible est-il resté tel que le cookbook l'a installé ?
is_pristine() { # dst
  local known; known="$(manifest_sha "$(rel_of "$1")")"
  [ -n "$known" ] && [ "$known" = "$(sha_of "$1")" ]
}

keep_custom() { # dst src raison
  local rel; rel="$(rel_of "$1")"
  local known; known="$(manifest_sha "$rel")"
  [ -z "$known" ] || record "$rel" "$known"
  echo -e "    ${YELLOW}= ${rel} ($3 : conservé)${NC}"
  CUSTOM_KEPT+=("$rel|$2")
  N_CUSTOM=$((N_CUSTOM+1))
}

backup_file() {
  local rel; rel="$(rel_of "$1")"
  [ -n "$BACKUP_DIR" ] || BACKUP_DIR="$TARGET/.claude/.cookbook-backup/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  cp -p "$1" "$BACKUP_DIR/$rel"
}

write_new() { # src dst
  if [ "$DRY" = false ]; then mkdir -p "$(dirname "$2")"; cp -p "$1" "$2"; fi
  echo "    + $(rel_of "$2")"
  N_ADDED=$((N_ADDED+1))
}

# Fichier géré par le cookbook : créé, ou mis à jour s'il n'a pas été adapté par
# le projet. Sinon conservé et signalé (--force pour l'écraser, avec sauvegarde).
put_managed() { # src dst
  local src_sha; src_sha="$(sha_of "$1")"
  if [ -f "$2" ]; then
    if cmp -s "$1" "$2"; then record "$(rel_of "$2")" "$src_sha"; N_SAME=$((N_SAME+1)); return 0; fi
    if ! is_pristine "$2" && [ "$FORCE" = false ]; then
      if [ -n "$(manifest_sha "$(rel_of "$2")")" ]; then keep_custom "$2" "$1" "adapté par le projet"
      else keep_custom "$2" "$1" "sans empreinte cookbook"; fi
      return 0
    fi
    if [ "$DRY" = false ]; then backup_file "$2"; cp -p "$1" "$2"; fi
    echo "    ~ $(rel_of "$2") (mis à jour$([ "$DRY" = false ] && echo ', ancienne version sauvegardée'))"
    N_UPDATED=$((N_UPDATED+1))
  else
    write_new "$1" "$2"
  fi
  record "$(rel_of "$2")" "$src_sha"
}

# Fichier du projet : créé s'il manque, jamais écrasé.
put_owned() { # src dst
  if [ -f "$2" ]; then
    N_KEPT=$((N_KEPT+1))
    cmp -s "$1" "$2" || KEPT_DIFF+=("$(rel_of "$2")|$1")
  else
    write_new "$1" "$2"
  fi
}

retire_file() { # chemin absolu dans la cible
  [ -f "$1" ] || return 0
  if ! is_pristine "$1" && [ "$FORCE" = false ]; then
    keep_custom "$1" "" "retiré du cookbook mais adapté par le projet"
    return 0
  fi
  if [ "$DRY" = false ]; then
    backup_file "$1"; rm -f "$1"
    local d; d="$(dirname "$1")"
    while [ "$d" != "$TARGET" ] && [ "$d" != "$TARGET/.claude" ] && rmdir "$d" 2>/dev/null; do d="$(dirname "$d")"; done
  fi
  echo "    - $(rel_of "$1") (retiré$([ "$DRY" = false ] && echo ', sauvegardé'))"
  N_RETIRED=$((N_RETIRED+1))
}

# Les étapes scripts/scan-secu.d/ ne servent qu'à l'orchestrateur modulaire du
# cookbook : inutile de les poser à côté d'un scan-secu.sh monolithique conservé.
scan_secu_modular() {
  [ ! -f "$TARGET/scan-secu.sh" ] || grep -q 'scan-secu\.d' "$TARGET/scan-secu.sh" \
    || [ "$FORCE" = true ]
}

# ── Cartographie source → cible ─────────────────────────────────────────────
# Sortie : "<source>\t<chemin relatif dans le projet>". $1 = core | <pack>
emit_map() {
  local name="$1" root f
  if [ "$name" = core ]; then root="$CORE"; else root="$COOKBOOK_ROOT/plugins/$name"; fi
  local agent_dir=".claude/agents/roles"
  [ "$name" = core ] || agent_dir=".claude/agents/stacks/$name"

  if [ -d "$root/agents" ]; then
    for f in "$root"/agents/*.md; do
      if [ "$name" = core ] && [ -n "$REPLACES" ] && [[ " $REPLACES " == *" $(basename "$f" .md) "* ]]; then continue; fi
      printf '%s\t%s\n' "$f" "$agent_dir/$(basename "$f")"
    done
  fi
  if [ -d "$root/skills" ]; then
    while IFS= read -r f; do printf '%s\t%s\n' "$f" ".claude/skills/${f#"$root"/skills/}"; done \
      < <(find "$root/skills" -type f ! -name .DS_Store | sort)
  fi
  if [ -d "$root/hooks" ]; then
    for f in "$root"/hooks/*.sh; do printf '%s\t%s\n' "$f" ".claude/hooks/$(basename "$f")"; done
  fi
  if [ -d "$root/scripts" ]; then
    while IFS= read -r f; do
      local r="${f#"$root"/scripts/}"
      if [ "$r" = "scan-secu.sh" ]; then printf '%s\t%s\n' "$f" "scan-secu.sh"
      elif [[ "$r" == scan-secu.d/* ]] && ! scan_secu_modular; then continue
      else printf '%s\t%s\n' "$f" "scripts/$r"; fi
    done < <(find "$root/scripts" -type f ! -name .DS_Store | sort)
  fi
  return 0
}

# ── 1. Nettoyage : fichiers retirés et fichiers d'un autre pack ─────────────
echo -e "${GREEN}[1/5]${NC} Nettoyage des fichiers périmés…"
while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  retire_file "$TARGET/$line"
done < "$CORE/retired.txt"

for p in "${PACKS[@]:-}"; do
  [ -n "$p" ] && [ "$p" != "$STACK" ] || continue
  while IFS=$'\t' read -r _ rel; do retire_file "$TARGET/$rel"; done < <(emit_map "$p")
  retire_file "$TARGET/docs/claude-config/stack-$p.md"
done
if [ -n "$REPLACES" ]; then
  for role in $REPLACES; do retire_file "$TARGET/.claude/agents/roles/$role.md"; done
fi
[ "$N_RETIRED" -gt 0 ] || echo "    (rien à retirer)"

# ── 2. Core + pack : agents, skills, hooks, scripts ─────────────────────────
echo -e "${GREEN}[2/5]${NC} Agents, skills, hooks, scripts…"
while IFS=$'\t' read -r src rel; do put_managed "$src" "$TARGET/$rel"; done < <(emit_map core)
if [ -n "$PACK" ]; then
  while IFS=$'\t' read -r src rel; do put_managed "$src" "$TARGET/$rel"; done < <(emit_map "$STACK")
fi
if [ "$DRY" = false ]; then
  chmod +x "$TARGET"/.claude/hooks/*.sh "$TARGET"/scan-secu.sh "$TARGET"/scripts/*.sh 2>/dev/null || true
fi

# ── 3. Docs ─────────────────────────────────────────────────────────────────
echo -e "${GREEN}[3/5]${NC} Docs…"
for f in feature-plan-template.md ux-audit-prompt.md; do put_managed "$COOKBOOK_ROOT/docs/$f" "$TARGET/docs/$f"; done
for f in experts.md setup.md; do put_managed "$COOKBOOK_ROOT/docs/claude-config/$f" "$TARGET/docs/claude-config/$f"; done
# Accumulés par le projet : jamais écrasés.
put_owned "$COOKBOOK_ROOT/docs/lessons.md" "$TARGET/docs/lessons.md"
put_owned "$COOKBOOK_ROOT/docs/anti-patterns.md" "$TARGET/docs/anti-patterns.md"
if [ -n "$PACK" ]; then
  put_managed "$PACK/README.md" "$TARGET/docs/claude-config/stack-$STACK.md"
  if [ -d "$PACK/docs" ]; then
    for f in "$PACK"/docs/*.md; do put_owned "$f" "$TARGET/docs/$(basename "$f")"; done
  fi
fi
while IFS= read -r f; do put_managed "$f" "$TARGET/docs/templates/${f#"$COOKBOOK_ROOT"/docs/templates/}"; done \
  < <(find "$COOKBOOK_ROOT/docs/templates" -type f ! -name .DS_Store | sort)

# ── 4. Config du projet (créée si absente, jamais écrasée) ──────────────────
echo -e "${GREEN}[4/5]${NC} Config…"
SETTINGS="$TARGET/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
  echo -e "    ${YELLOW}.claude/settings.json existe : préservé${NC} (référence : docs/templates/settings.json)"
  N_KEPT=$((N_KEPT+1))
else
  if [ "$DRY" = false ]; then
    mkdir -p "$TARGET/.claude"
    if [ -n "$PACK" ] && [ -f "$PACK/settings.hooks.json" ] && command -v jq >/dev/null 2>&1; then
      jq -s '.[0] * .[1]' "$COOKBOOK_ROOT/docs/templates/settings.json" "$PACK/settings.hooks.json" > "$SETTINGS"
    else
      cp "$COOKBOOK_ROOT/docs/templates/settings.json" "$SETTINGS"
      if [ -n "$PACK" ] && [ -f "$PACK/settings.hooks.json" ]; then
        echo -e "    ${YELLOW}jq absent : ajouter à la main les hooks du pack (plugins/${STACK}/settings.hooks.json)${NC}"
      fi
    fi
  fi
  echo "    + .claude/settings.json (deny + hooks$([ -n "$PACK" ] && echo ' + hooks du pack'))"
  N_ADDED=$((N_ADDED+1))
fi
# Hooks d'un pack non retenu encore référencés dans les settings : ils échoueraient à chaque appel.
if [ -f "$SETTINGS" ]; then
  for p in "${PACKS[@]:-}"; do
    [ -n "$p" ] && [ "$p" != "$STACK" ] && [ -d "$COOKBOOK_ROOT/plugins/$p/hooks" ] || continue
    for h in "$COOKBOOK_ROOT"/plugins/"$p"/hooks/*.sh; do
      if grep -q "$(basename "$h")" "$SETTINGS" 2>/dev/null; then
        echo -e "    ${YELLOW}ATTENTION${NC}: .claude/settings.json référence encore le hook $(basename "$h") (pack $p, retiré) : supprimer cette entrée."
      fi
    done
  done
fi
put_owned "$COOKBOOK_ROOT/docs/templates/mcp.json" "$TARGET/.mcp.json"
if [ "$UPDATE_MODE" = false ]; then put_owned "$COOKBOOK_ROOT/docs/templates/CLAUDE.md" "$TARGET/CLAUDE.md"; fi

# ── 5. Outillage git (opt-in) ───────────────────────────────────────────────
echo -e "${GREEN}[5/5]${NC} Outillage git…"
if [ "$GIT_TOOLING" = true ]; then
  for f in commitlint.config.js lefthook.yml .markdownlint.json; do put_owned "$COOKBOOK_ROOT/$f" "$TARGET/$f"; done
  echo -e "    ${YELLOW}NOTE${NC}: npm i -D @commitlint/cli @commitlint/config-conventional lefthook markdownlint-cli"
else
  echo "    (ignoré — ajouter --with-git-tooling pour commitlint + lefthook + markdownlint)"
fi

# ── Manifeste ───────────────────────────────────────────────────────────────
if [ "$DRY" = false ]; then
  mkdir -p "$TARGET/.claude"
  sort -u "$MANIFEST_NEW" > "$MANIFEST"
fi

# ── Récap ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}══ Terminé$([ "$DRY" = true ] && echo ' (dry-run : rien n’a été écrit)') ══${NC}"
echo "  ajoutés : $N_ADDED · mis à jour : $N_UPDATED · identiques : $N_SAME · retirés : $N_RETIRED · conservés (projet) : $N_KEPT · adaptés conservés : $N_CUSTOM"
if [ -n "$BACKUP_DIR" ]; then
  echo -e "  sauvegardes : ${BLUE}$(rel_of "$BACKUP_DIR")${NC} (à ajouter au .gitignore)"
fi
if [ "${#CUSTOM_KEPT[@]}" -gt 0 ]; then
  echo -e "  ${YELLOW}Fichiers gérés adaptés par le projet, non modifiés (--force pour écraser) :${NC}"
  for e in "${CUSTOM_KEPT[@]}"; do
    if [ -n "${e#*|}" ]; then echo "    - ${e%%|*}   (comparer : diff ${e%%|*} ${e#*|})"
    else echo "    - ${e%%|*}   (retiré du cookbook : supprimer à la main si inutile)"; fi
  done
fi
if [ "${#KEPT_DIFF[@]}" -gt 0 ]; then
  echo -e "  ${YELLOW}Fichiers du projet différents de la version cookbook (non modifiés) :${NC}"
  for e in "${KEPT_DIFF[@]}"; do echo "    - ${e%%|*}   (comparer : diff ${e%%|*} ${e#*|})"; done
fi
if [ "$DRY" = false ]; then
  _n() { find "$@" -type f 2>/dev/null | wc -l | tr -d ' '; }
  echo "  installé : $(_n "$TARGET/.claude/agents" -name '*.md') agents · $(find "$TARGET/.claude/skills" -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l | tr -d ' ') skills · $(_n "$TARGET/.claude/hooks" -name '*.sh') hooks · $(_n "$TARGET/scripts/scan-secu.d" -name 'step-*.sh') étapes scan-secu"
fi

if [ "$DRY" = false ] && [ "$UPDATE_MODE" = false ]; then
  echo ""
  echo -e "${BOLD}Prochaines étapes${NC}"
  echo "  1. Éditer CLAUDE.md : stack, conventions, Domain Model Glossary (PRIMARY_MODELS)"
  echo "  2. Redémarrer Claude Code pour activer les hooks de .claude/settings.json"
  echo "  3. Nouvelle feature : /feature (product-strategist si PRODUCT.md ou docs/vision.md existe)"
  echo "  4. Avant commit : le reviewer final ; avant push : bash scan-secu.sh --full"
  echo "  5. Optionnel : docs/templates/{husky-pre-commit.sh, scan-secu-weekly.yml, .gitleaks.toml}"
  echo "  Doc : docs/claude-config/setup.md · catalogue : docs/claude-config/experts.md"
fi
