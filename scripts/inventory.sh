#!/usr/bin/env bash
# Inventaire du cookbook généré depuis le filesystem — source unique des comptes.
# Usage : bash scripts/inventory.sh [--json]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

count() { find "$@" -type f 2>/dev/null | wc -l | tr -d ' '; }

ROLES=$(count .claude/agents/roles -name '*.md')
STACK_AGENTS=$(count .claude/agents/stacks -name '*.md')
SKILLS=$(find .claude/skills -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
COMMANDS=$(count .claude/commands -name '*.md')
HOOKS=$(count .claude/hooks -name '*.sh')
SECU_STEPS=$(count scripts/scan-secu.d -name 'step-*.sh')
CAPABILITIES=$(count .claude/skills/prod-readiness/capabilities -name '*.yaml')
TEMPLATES=$(count docs/templates)
VERSION=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' .claude-plugin/plugin.json | head -1)

if [ "${1:-}" = "--json" ]; then
  printf '{"version":"%s","roles":%s,"stack_agents":%s,"skills":%s,"commands":%s,"hooks":%s,"scan_secu_steps":%s,"prod_readiness_capabilities":%s,"templates":%s}\n' \
    "$VERSION" "$ROLES" "$STACK_AGENTS" "$SKILLS" "$COMMANDS" "$HOOKS" "$SECU_STEPS" "$CAPABILITIES" "$TEMPLATES"
  exit 0
fi

cat <<EOF
claude-cookbook v${VERSION}

  roles (generic agents)      ${ROLES}   .claude/agents/roles/
  stack agents                ${STACK_AGENTS}   .claude/agents/stacks/
  skills                      ${SKILLS}   .claude/skills/
  commands                    ${COMMANDS}   .claude/commands/
  hooks                       ${HOOKS}   .claude/hooks/
  scan-secu steps             ${SECU_STEPS}   scripts/scan-secu.d/
  prod-readiness capabilities ${CAPABILITIES}   .claude/skills/prod-readiness/capabilities/
  templates                   ${TEMPLATES}   docs/templates/
EOF
