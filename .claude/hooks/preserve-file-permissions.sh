#!/usr/bin/env bash
# ============================================================================
# preserve-file-permissions.sh — fix chmod loss macOS/Linux edit
#
# Pattern : sur PreToolUse Edit/Write/MultiEdit, snapshot chmod du fichier.
# Sur PostToolUse, restore chmod snapshoté (Claude Code reset à 644 par défaut
# lors d'un Write, ce qui casse les scripts exécutables).
#
# Cache : /tmp/claude_file_permissions.txt (persist entre calls du hook).
# Log debug : /tmp/claude_permissions_debug.log
#
# Wire dans settings.json :
#   "hooks": {
#     "PreToolUse":  [{ "matcher": "Edit|Write|MultiEdit", "hooks": [{ "type": "command",
#         "command": "${CLAUDE_PLUGIN_ROOT}/.claude/hooks/preserve-file-permissions.sh" }] }],
#     "PostToolUse": [{ "matcher": "Edit|Write|MultiEdit", "hooks": [{ "type": "command",
#         "command": "${CLAUDE_PLUGIN_ROOT}/.claude/hooks/preserve-file-permissions.sh" }] }]
#   }
# ============================================================================

DEBUG_LOG="/tmp/claude_permissions_debug.log"
PERMISSIONS_CACHE="/tmp/claude_file_permissions.txt"

input_json=$(cat)

hook_type=$(echo "$input_json" | jq -r '.hook_event_name // ""')
tool_name=$(echo "$input_json" | jq -r '.tool_name // ""')
file_path=$(echo "$input_json" | jq -r '.tool_input.file_path // ""')

echo "[$(date)] Hook: $hook_type, Tool: $tool_name, File: $file_path" >>"$DEBUG_LOG"

# Only intercept Edit/Write/MultiEdit — passthrough for others
case "$tool_name" in
  Write | Edit | MultiEdit) ;;
  *) echo "$input_json"; exit 0 ;;
esac

[ -z "$file_path" ] && { echo "$input_json"; exit 0; }

if [ "$hook_type" = "PreToolUse" ]; then
  # Snapshot chmod si fichier existe
  if [ -f "$file_path" ]; then
    current_perms=$(stat -f "%OLp" "$file_path" 2>/dev/null || stat -c "%a" "$file_path" 2>/dev/null)
    if [ -n "$current_perms" ]; then
      echo "${file_path}:${current_perms}" >>"$PERMISSIONS_CACHE"
      echo "[$(date)] PreToolUse: Saved $file_path with permissions $current_perms" >>"$DEBUG_LOG"
    fi
  fi
elif [ "$hook_type" = "PostToolUse" ]; then
  # Restore chmod depuis cache
  if [ -f "$PERMISSIONS_CACHE" ]; then
    saved_entry=$(grep "^${file_path}:" "$PERMISSIONS_CACHE" | tail -1)
    if [ -n "$saved_entry" ]; then
      saved_perms=$(echo "$saved_entry" | cut -d: -f2)
      if [ -n "$saved_perms" ] && [ -f "$file_path" ]; then
        chmod "$saved_perms" "$file_path" 2>/dev/null
        if [ $? -eq 0 ]; then
          echo "[$(date)] PostToolUse: Restored $file_path to permissions $saved_perms" >>"$DEBUG_LOG"
          # Re-restore async après 3s (Claude Code peut reset async après hook)
          (
            sleep 3
            chmod "$saved_perms" "$file_path" 2>/dev/null
            echo "[$(date)] PostToolUse: Re-restored $file_path to $saved_perms (delayed 3s)" >>"$DEBUG_LOG"
          ) &
          # Purge entry cache
          grep -v "^${file_path}:" "$PERMISSIONS_CACHE" >"${PERMISSIONS_CACHE}.tmp" 2>/dev/null || true
          mv "${PERMISSIONS_CACHE}.tmp" "$PERMISSIONS_CACHE" 2>/dev/null || true
        fi
      fi
    fi
  fi
fi

# Passthrough JSON unchanged
echo "$input_json"
