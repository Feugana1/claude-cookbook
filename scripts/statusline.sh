#!/usr/bin/env bash
# ============================================================================
# statusline.sh — Claude Code statusline (model + $/day + %tokens)
#
# Wire dans settings.json :
#   "statusLine": {
#     "type": "command",
#     "command": "${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh",
#     "refreshInterval": 30
#   }
#
# Dépendance optionnelle : `ccusage` (npm) pour le cost. Degradation gracieuse
# si absent (affiche "0.00" et un warning debug).
#
# Read stdin JSON (model, session_id, workspace.current_dir).
# Output stdout 1 ligne : model + cost/jour + %tokens.
# ============================================================================

readonly MAX_CONTEXT=160000  # 200K * 0.8
readonly CACHE_FILE="/tmp/claude_statusline_cost_cache"
readonly CACHE_TTL=60  # seconds

calculate_daily_cost() {
  if ! command -v ccusage >/dev/null 2>&1; then
    echo "0"
    return
  fi

  local today
  today=$(date +%Y%m%d)

  local ccusage_output
  ccusage_output=$(ccusage daily --json --since "$today" --until "$today" 2>/dev/null)

  if [ -z "$ccusage_output" ]; then
    echo "0"
    return
  fi

  local cost
  cost=$(echo "$ccusage_output" | jq -r ".daily | to_entries | .[0].value.totalCost // 0" 2>/dev/null)

  if [ -n "$cost" ] && [ "$cost" != "0" ]; then
    echo "$cost"
  else
    echo "0"
  fi
}

get_cached_cost() {
  local today
  today=$(date +%Y-%m-%d)

  if [ -f "$CACHE_FILE" ]; then
    local cache_date cache_cost cache_age
    cache_date=$(head -1 "$CACHE_FILE" 2>/dev/null)
    cache_cost=$(tail -1 "$CACHE_FILE" 2>/dev/null)
    cache_age=$(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)))

    if [ "$cache_date" = "$today" ] && [ "$cache_age" -le "$CACHE_TTL" ]; then
      echo "${cache_cost:-0.00}"
      return
    fi
  fi

  local cost
  cost=$(calculate_daily_cost)
  cost="${cost:-0.00}"

  echo "$today" >"$CACHE_FILE"
  echo "$cost" >>"$CACHE_FILE"

  echo "$cost"
}

calculate_usage_percentage() {
  local total_tokens="$1"

  if [ "$MAX_CONTEXT" -eq 0 ]; then
    echo "0.0"
    return
  fi

  local usage_percent
  usage_percent=$(echo "scale=1; $total_tokens * 100 / $MAX_CONTEXT" | bc -l 2>/dev/null || echo "0")

  if (($(echo "$usage_percent > 100" | bc -l 2>/dev/null))); then
    echo "100.0"
  else
    echo "$usage_percent"
  fi
}

get_token_usage() {
  local session_id="$1"
  local transcript_dir="$2"
  local transcript_file="$transcript_dir/$session_id.jsonl"

  if [ ! -f "$transcript_file" ]; then
    echo "0"
    return
  fi

  local last_usage
  last_usage=$(grep '"usage"' "$transcript_file" 2>/dev/null | tail -1 | jq '.message.usage' 2>/dev/null)

  if [ -z "$last_usage" ] || [ "$last_usage" = "null" ]; then
    echo "0"
    return
  fi

  local input output cache_creation cache_read
  input=$(echo "$last_usage" | jq -r '.input_tokens // 0')
  output=$(echo "$last_usage" | jq -r '.output_tokens // 0')
  cache_creation=$(echo "$last_usage" | jq -r '.cache_creation_input_tokens // 0')
  cache_read=$(echo "$last_usage" | jq -r '.cache_read_input_tokens // 0')

  echo $((input + output + cache_creation + cache_read))
}

main() {
  local json_input
  json_input=$(cat)

  local model session_id current_dir
  model=$(echo "$json_input" | jq -r '.model.display_name // .model // "unknown"' 2>/dev/null)
  session_id=$(echo "$json_input" | jq -r '.session_id // ""' 2>/dev/null)
  current_dir=$(echo "$json_input" | jq -r '.workspace.current_dir // .cwd // "~"' 2>/dev/null)

  local project_name transcript_dir
  project_name="${current_dir//[\/.]/-}"
  transcript_dir="$HOME/.claude/projects/$project_name"

  local total_tokens=0
  if [ -n "$session_id" ] && [ -d "$transcript_dir" ]; then
    total_tokens=$(get_token_usage "$session_id" "$transcript_dir")
  fi

  local usage_percent
  usage_percent=$(calculate_usage_percentage "$total_tokens")

  local today_cost
  today_cost=$(get_cached_cost)
  today_cost=$(printf "%.2f" "$today_cost")

  printf "🤖 %s | 💰 \$%s | 📊 %s%%\n" "$model" "$today_cost" "$usage_percent"
}

main "$@"
