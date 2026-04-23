#!/usr/bin/env bash
# Claude Code rich status line
# Input: JSON via stdin

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  cat <<EOF
Usage: statusline-command.sh [--help]

Rich Claude Code status line — 3 lines.

Line 1  identity:   cwd  git-branch  [style if non-default]
Line 2  model:      model  effort  version  id: <full session id>
Line 3  session:    ctx used/max  output tokens  cache hits  cost  duration  lines +/-
Line 4  limits:     5-hour rate  7-day rate  current time
Warning:            exceeds-200k flag shown in red when set

JSON fields used:
  workspace.current_dir | cwd                      Working directory
  session_id                                        Session identifier
  model.display_name                                Model name
  version                                           Claude Code version
  output_style.name                                 Output style
  context_window.used_percentage                    Context usage (%)
  context_window.context_window_size                Max context tokens
  context_window.total_output_tokens                Total output tokens generated
  context_window.current_usage.cache_read_input_tokens   Cache hits (tokens)
  context_window.current_usage.cache_creation_input_tokens Cache writes (tokens)
  exceeds_200k_tokens                               Over-limit warning flag
  cost.total_cost_usd                               Session cost (USD)
  cost.total_lines_added                            Lines added this session
  cost.total_lines_removed                          Lines removed this session
  rate_limits.five_hour.used_percentage             5-hour rate limit usage (%)
  rate_limits.five_hour.resets_at                   5-hour reset time (unix)
  rate_limits.seven_day.used_percentage             7-day rate limit usage (%)
  rate_limits.seven_day.resets_at                   7-day reset time (unix)
EOF
  exit 0
fi

input=$(cat)

# ── ANSI codes ────────────────────────────────────────────────────────────────
ESC=$'\033'
RESET="${ESC}[0m"
BOLD="${ESC}[1m"
DIM="${ESC}[2m"
CYAN="${ESC}[36m"
YELLOW="${ESC}[33m"
MAGENTA="${ESC}[35m"
GREEN="${ESC}[32m"
RED="${ESC}[31m"
GREY="${ESC}[90m"
BLUE="${ESC}[34m"
WHITE="${ESC}[97m"

# ── Extract fields ────────────────────────────────────────────────────────────
cwd=$(echo "$input"          | jq -r '.workspace.current_dir // .cwd // ""')
session_id=$(echo "$input"   | jq -r '.session_id // ""')
model=$(echo "$input"        | jq -r '.model.display_name // ""')
version=$(echo "$input"      | jq -r '.version // ""')
output_style=$(echo "$input" | jq -r '.output_style.name // ""')
effort=$(jq -r '.effortLevel // "auto"' "$HOME/.claude/settings.json" 2>/dev/null)
[ -z "$effort" ] && effort="auto"

ctx=$(echo "$input"          | jq -r '.context_window.used_percentage // ""')
ctx_max=$(echo "$input"      | jq -r '.context_window.context_window_size // ""')
ctx_out=$(echo "$input"      | jq -r '.context_window.total_output_tokens // ""')
ctx_cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // ""')
ctx_cache_write=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // ""')
exceeds=$(echo "$input"      | jq -r '.exceeds_200k_tokens // false')

cost=$(echo "$input"            | jq -r '.cost.total_cost_usd // ""')
total_dur_ms=$(echo "$input"    | jq -r '.cost.total_duration_ms // ""')
lines_added=$(echo "$input"     | jq -r '.cost.total_lines_added // ""')
lines_removed=$(echo "$input"   | jq -r '.cost.total_lines_removed // ""')

api_call_ms=$(echo "$input"  | jq -r '.cost.total_api_duration_ms // ""')

five_pct=$(echo "$input"     | jq -r '.rate_limits.five_hour.used_percentage // ""')
five_reset=$(echo "$input"   | jq -r '.rate_limits.five_hour.resets_at // ""')
seven_pct=$(echo "$input"    | jq -r '.rate_limits.seven_day.used_percentage // ""')
seven_reset=$(echo "$input"  | jq -r '.rate_limits.seven_day.resets_at // ""')

# Derive used tokens from percentage × window size
ctx_used=""
if [ -n "$ctx" ] && [ -n "$ctx_max" ] && [[ "$ctx_max" =~ ^[0-9]+$ ]]; then
  ctx_used=$(awk "BEGIN{printf \"%d\", $ctx_max * $ctx / 100}")
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
home="$HOME"
short_cwd="${cwd/#$home/\~}"

# Color for a percentage value: green < 50, yellow < 80, red >= 80
pct_color() {
  local val
  val=$(printf '%.0f' "$1" 2>/dev/null) || return
  if   [ "$val" -lt 50 ]; then printf '%s' "$GREEN"
  elif [ "$val" -lt 80 ]; then printf '%s' "$YELLOW"
  else                         printf '%s' "$RED"
  fi
}

# Format a token count: 388 → 388, 8511 → 8.5k, 1200000 → 1.2M
fmt_tokens() {
  local n="$1"
  [[ "$n" =~ ^[0-9]+$ ]] || return
  if   [ "$n" -ge 1000000 ]; then awk "BEGIN{printf \"%.1fM\", $n/1000000}"
  elif [ "$n" -ge 1000 ];    then awk "BEGIN{printf \"%.1fk\", $n/1000}"
  else                            printf '%d' "$n"
  fi
}


# ── Session duration (from authoritative JSON total_duration_ms) ──────────────
dur_fmt=""
if [[ "$total_dur_ms" =~ ^[0-9]+$ ]]; then
  elapsed=$(( total_dur_ms / 1000 ))
  hrs=$(( elapsed / 3600 ))
  mins=$(( (elapsed % 3600) / 60 ))
  secs=$(( elapsed % 60 ))
  if [ "$hrs" -gt 0 ]; then
    dur_fmt=$(printf '%dh%02dm' "$hrs" "$mins")
  else
    dur_fmt=$(printf '%dm%02ds' "$mins" "$secs")
  fi
fi

# ── Git branch + dirty indicator ─────────────────────────────────────────────
git_seg=""
if cd "$cwd" 2>/dev/null && git rev-parse --is-inside-work-tree --no-optional-locks >/dev/null 2>&1; then
  branch=$(git --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
           || git --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    # Truncate long branch names to 25 characters
    if [ "${#branch}" -gt 25 ]; then
      branch="${branch:0:24}…"
    fi
    dirty=""
    if ! git --no-optional-locks diff --quiet 2>/dev/null || \
       ! git --no-optional-locks diff --cached --quiet 2>/dev/null; then
      dirty=" ${YELLOW}●${RESET}"
    elif [ -n "$(git --no-optional-locks ls-files --others --exclude-standard 2>/dev/null)" ]; then
      dirty=" ${GREY}○${RESET}"
    fi
    git_seg="  ${CYAN}${branch}${RESET}${dirty}"
  fi
fi

# ── Divider ───────────────────────────────────────────────────────────────────
DIV="${GREY} │ ${RESET}"

# ── Render ────────────────────────────────────────────────────────────────────

# ── Line 1: Identity ──────────────────────────────────────────────────────────
# ~/path  branch ●  [style if non-default]
style_part=""
[ -n "$output_style" ] && [ "$output_style" != "default" ] && \
  style_part="${DIV}${WHITE}style: ${RESET}${output_style}"

printf '%s%s%s%s%s\n' \
  "${BOLD}${MAGENTA}" "$short_cwd" "${RESET}" \
  "$git_seg" \
  "$style_part"

# ── Line 2: Model, effort, version, session id ────────────────────────────────
# Model  effort: auto  v2.1.87  id: <session-id>
case "$effort" in
  auto)   effort_color="$CYAN"             ;;
  low)    effort_color="$GREEN"            ;;
  medium) effort_color="$YELLOW"           ;;
  high)   effort_color="$RED"              ;;
  max)    effort_color="${BOLD}${RED}"     ;;
  *)      effort_color="$WHITE"            ;;
esac
effort_part="${DIV}${WHITE}effort: ${effort_color}${effort}${RESET}"

session_id_part=""
[ -n "$session_id" ] && session_id_part="${DIV}${GREY}id: ${RESET}${session_id}"

printf '%s%s%s%s%s%s\n' \
  "${YELLOW}" "$model" "${RESET}" \
  "$effort_part" \
  "${DIV}${WHITE}v${RESET}${version}" \
  "$session_id_part"

# ── Line 3: Context, tokens & cache ──────────────────────────────────────────
# context: 34k/200k  ⚠ 72% │ tokens out: 22k │ cache hit: 54k  cache write: 180
ctx_part=""
if [ -n "$ctx" ]; then
  color=$(pct_color "$ctx")
  used_fmt=$(fmt_tokens "$ctx_used")
  max_fmt=$(fmt_tokens "$ctx_max")
  if [ -n "$used_fmt" ] && [ -n "$max_fmt" ]; then
    ctx_part="${WHITE}context: ${color}${used_fmt}/${max_fmt}${RESET}"
  else
    ctx_part="${WHITE}context: ${color}$(printf '%.0f' "$ctx")%${RESET}"
  fi
  [ "$exceeds" = "true" ] && ctx_part="${ctx_part} ${RED}${BOLD}⚠ exceeds 200k${RESET}"
  if [[ "$ctx" =~ ^[0-9]+$ ]] && [ "$ctx" -ge 80 ]; then
    ctx_part="${ctx_part} ${BOLD}${RED}⚠ run /compact${RESET}"
  fi
fi

out_part=""
out_fmt=$(fmt_tokens "$ctx_out")
[ -n "$out_fmt" ] && out_part="${WHITE}tokens out: ${BLUE}${out_fmt}${RESET}"

cache_part=""
cr_fmt=$(fmt_tokens "$ctx_cache_read")
cw_fmt=$(fmt_tokens "$ctx_cache_write")
if [ -n "$cr_fmt" ] || [ -n "$cw_fmt" ]; then
  cache_parts=""
  if [ -n "$cr_fmt" ]; then
    saved_str=""
    if [[ "$ctx_cache_read" =~ ^[0-9]+$ ]]; then
      session_savings=$(awk "BEGIN{printf \"%.6f\", $ctx_cache_read * 2.70 / 1000000}")
      savings_dir="$HOME/.claude/cache_savings"
      mkdir -p "$savings_dir"
      [ -n "$session_id" ] && printf '%s' "$session_savings" > "${savings_dir}/${session_id//[^a-zA-Z0-9_-]/}"
      total_savings=$(awk '{s+=$1} END{printf "%.4f", s+0}' "${savings_dir}"/* 2>/dev/null)
      saved_str=" ${WHITE}saved: ${GREEN}\$$(printf '%.4f' "$session_savings")${RESET}"
      [ -n "$total_savings" ] && saved_str="${saved_str} ${WHITE}(total: ${GREEN}\$${total_savings}${WHITE})${RESET}"
    fi
    cache_parts="${WHITE}cache hit: ${GREEN}${cr_fmt}${RESET}${saved_str}"
  fi
  [ -n "$cw_fmt" ] && cache_parts="${cache_parts} ${WHITE}cache write: ${GREY}${cw_fmt}${RESET}"
  cache_part="$cache_parts"
fi

line2_parts=()
[ -n "$ctx_part"   ] && line2_parts+=("$ctx_part")
[ -n "$out_part"   ] && line2_parts+=("$out_part")
[ -n "$cache_part" ] && line2_parts+=("$cache_part")

line2=""
for part in "${line2_parts[@]}"; do [ -n "$line2" ] && line2+="$DIV"; line2+="$part"; done
[ -n "$line2" ] && printf '%s\n' "$line2"

# ── Line 3: Cost, session & edits ─────────────────────────────────────────────
# cost: $0.978 (total: $3.241) │ session: 12m30s │ lines: +201 / -145
cost_part=""
if [ -n "$cost" ]; then
  costs_dir="$HOME/.claude/costs"
  mkdir -p "$costs_dir"
  [ -n "$session_id" ] && printf '%s' "$cost" > "${costs_dir}/${session_id//[^a-zA-Z0-9_-]/}"
  total_cost=$(awk '{s+=$1} END{printf "%.3f", s+0}' "${costs_dir}"/* 2>/dev/null)
  cost_part="${WHITE}cost: ${RESET}\$$(printf '%.3f' "$cost")"
  [ -n "$total_cost" ] && cost_part="${cost_part} ${WHITE}(total: ${RESET}\$${total_cost}${WHITE})${RESET}"
fi

api_time_part=""
if [[ "$api_call_ms" =~ ^[0-9]+$ ]]; then
  api_secs=$(( api_call_ms / 1000 ))
  api_hrs=$(( api_secs / 3600 ))
  api_mins=$(( (api_secs % 3600) / 60 ))
  api_s=$(( api_secs % 60 ))
  if [ "$api_hrs" -gt 0 ]; then
    api_time_fmt=$(printf '%dh%02dm' "$api_hrs" "$api_mins")
  else
    api_time_fmt=$(printf '%dm%02ds' "$api_mins" "$api_s")
  fi
  api_time_part="${WHITE}api: ${BLUE}${api_time_fmt}${RESET}"
fi

dur_part=""
if [ -n "$dur_fmt" ]; then
  dur_part="${WHITE}session: ${RESET}${dur_fmt}"
  [ -n "$api_time_part" ] && dur_part="${dur_part} ${GREY}(${RESET}${api_time_part}${GREY})${RESET}"
fi

lines_part=""
if [[ "$lines_added" =~ ^[0-9]+$ ]] || [[ "$lines_removed" =~ ^[0-9]+$ ]]; then
  la="${lines_added:-0}"; lr="${lines_removed:-0}"
  lines_part="${WHITE}lines: ${GREEN}+${la}${RESET} ${WHITE}/ ${RED}-${lr}${RESET}"
fi

line3_parts=()
[ -n "$cost_part"  ] && line3_parts+=("$cost_part")
[ -n "$dur_part"   ] && line3_parts+=("$dur_part")
[ -n "$lines_part" ] && line3_parts+=("$lines_part")

line3=""
for part in "${line3_parts[@]}"; do [ -n "$line3" ] && line3+="$DIV"; line3+="$part"; done
[ -n "$line3" ] && printf '%s\n' "$line3"

# ── Line 4: Rate limits ───────────────────────────────────────────────────────
# 5h limit: 17%  resets in 2h30m (14:32) │ 7d limit: 27%  resets in 3d14h (19-04)

fmt_remaining() {
  local secs="$1"
  [[ "$secs" =~ ^[0-9]+$ ]] || return
  local days=$(( secs / 86400 ))
  local hrs=$(( (secs % 86400) / 3600 ))
  local mins=$(( (secs % 3600) / 60 ))
  if   [ "$days" -gt 0 ]; then printf '%dd%02dh' "$days" "$hrs"
  elif [ "$hrs"  -gt 0 ]; then printf '%dh%02dm' "$hrs"  "$mins"
  else                         printf '%dm'       "$mins"
  fi
}

now_ts=$(date +%s)

five_part=""
if [ -n "$five_pct" ]; then
  color=$(pct_color "$five_pct")
  remaining_str=""
  if [[ "$five_reset" =~ ^[0-9]+$ ]]; then
    secs_left=$(( five_reset - now_ts ))
    exact=$(date -r "$five_reset" '+%H:%M' 2>/dev/null)
    if [ "$secs_left" -gt 0 ]; then
      remaining_str=" ${WHITE}resets in ${RESET}$(fmt_remaining "$secs_left") (${exact})${RESET}"
    fi
  fi
  five_part="${WHITE}5h limit: ${color}$(printf '%.0f' "$five_pct")%${RESET}${remaining_str}"
fi

seven_part=""
if [ -n "$seven_pct" ]; then
  color=$(pct_color "$seven_pct")
  remaining_str=""
  if [[ "$seven_reset" =~ ^[0-9]+$ ]]; then
    secs_left=$(( seven_reset - now_ts ))
    exact=$(date -r "$seven_reset" '+%d-%m %H:%M' 2>/dev/null)
    if [ "$secs_left" -gt 0 ]; then
      remaining_str=" ${WHITE}resets in ${RESET}$(fmt_remaining "$secs_left") (${exact})${RESET}"
    fi
  fi
  seven_part="${WHITE}7d limit: ${color}$(printf '%.0f' "$seven_pct")%${RESET}${remaining_str}"
fi

line4_parts=()
[ -n "$five_part"  ] && line4_parts+=("$five_part")
[ -n "$seven_part" ] && line4_parts+=("$seven_part")

line4=""
for part in "${line4_parts[@]}"; do
  [ -n "$line4" ] && line4+="$DIV"
  line4+="$part"
done
[ -n "$line4" ] && printf '%s\n' "$line4"
