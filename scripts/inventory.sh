#!/usr/bin/env bash
# Inventaire du cookbook généré depuis le filesystem — source unique des comptes.
# Usage : bash scripts/inventory.sh [--json]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

count() { find "$@" -type f 2>/dev/null | wc -l | tr -d ' '; }

CORE=plugins/core
PACKS=$(find plugins -mindepth 1 -maxdepth 1 -type d ! -name core 2>/dev/null | sort)

ROLES=$(count $CORE/agents -name '*.md')
SKILLS=$(find $CORE/skills -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
COMMANDS=$(count $CORE/commands -name '*.md')
HOOKS=$(count $CORE/hooks -name '*.sh')
SECU_STEPS=$(count $CORE/scripts/scan-secu.d -name 'step-*.sh')
CAPABILITIES=$(count $CORE/skills/prod-readiness/capabilities -name '*.yaml')
TEMPLATES=$(count docs/templates)
VERSION=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' $CORE/.claude-plugin/plugin.json | head -1)

pack_json=""
pack_txt=""
for p in $PACKS; do
  n=$(basename "$p")
  a=$(count "$p/agents" -name '*.md')
  sk=$(find "$p/skills" -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
  h=$(count "$p/hooks" -name '*.sh')
  st=$(count "$p/scripts/scan-secu.d" -name 'step-*.sh')
  pack_json="${pack_json:+$pack_json,}\"$n\":{\"agents\":$a,\"skills\":$sk,\"hooks\":$h,\"scan_secu_steps\":$st}"
  pack_txt="${pack_txt}  pack ${n}: agents ${a} · skills ${sk} · hooks ${h} · scan-secu steps ${st}   ${p}/"$'\n'
done

if [ "${1:-}" = "--json" ]; then
  printf '{"version":"%s","core":{"agents":%s,"skills":%s,"commands":%s,"hooks":%s,"scan_secu_steps":%s,"prod_readiness_capabilities":%s},"packs":{%s},"templates":%s}\n' \
    "$VERSION" "$ROLES" "$SKILLS" "$COMMANDS" "$HOOKS" "$SECU_STEPS" "$CAPABILITIES" "$pack_json" "$TEMPLATES"
  exit 0
fi

cat <<TXT
claude-cookbook v${VERSION}

core  (${CORE}/)
  agents                      ${ROLES}
  skills                      ${SKILLS}
  commands                    ${COMMANDS}
  hooks                       ${HOOKS}
  scan-secu steps             ${SECU_STEPS}
  prod-readiness capabilities ${CAPABILITIES}

${pack_txt}
templates                     ${TEMPLATES}   docs/templates/
TXT
