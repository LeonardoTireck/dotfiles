#!/usr/bin/env bash
# Claude Code status line: repo ⎇ branch │ PR │ model · effort │ context │ 5h usage │ 7d usage
# Reads the session JSON from stdin (see https://code.claude.com/docs/en/statusline).

input=$(cat)
now=$(date +%s)

US=$'\x1f'
IFS="$US" read -r dir proj model_id model_name effort fast pr_num pr_url pr_state \
  ctx_size ctx_tok cache_cold five_pct five_reset week_pct week_reset < <(
  jq -r '[
    (.workspace.current_dir // .cwd // ""),
    (.workspace.project_dir // ""),
    (.model.id // ""),
    (.model.display_name // ""),
    (.effort.level // ""),
    (if .fast_mode == true then "1" else "" end),
    (.pr.number // ""),
    (.pr.url // ""),
    (.pr.review_state // ""),
    (.context_window.context_window_size // ""),
    (.context_window as $cw
      | if $cw.current_usage then
          ($cw.current_usage | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))
        elif ($cw.used_percentage and $cw.context_window_size) then
          ($cw.used_percentage * $cw.context_window_size / 100 | round)
        else "" end),
    (.prompt_cache
      | if . and .caching_observed and (.warm == false or (.expires_at != null and .expires_at <= now))
        then "1" else "" end),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.used_percentage // ""),
    (.rate_limits.seven_day.resets_at // "")
  ] | map(tostring) | join("\u001f")' <<<"$input"
)

ESC=$'\033'
RST="${ESC}[0m"
DIM="${ESC}[2m"
BOLD="${ESC}[1m"
RED="${ESC}[31m"
GREEN="${ESC}[32m"
YELLOW="${ESC}[33m"
BLUE="${ESC}[34m"
MAGENTA="${ESC}[35m"
CYAN="${ESC}[36m"
SEP=" ${DIM}│${RST} "

# Leave a little room for Claude Code's own padding around the status line.
max_width=$(( ${COLUMNS:-200} - 4 ))

# vislen <text>: visible width, ignoring ANSI colors and OSC 8 links
vislen() {
  printf '%s' "$1" | perl -CS -ne 's/\e\]8;;[^\a]*\a//g; s/\e\[[0-9;]*m//g; print length'
}

level_color() {
  if [ "$1" -ge 80 ]; then printf '%s' "$RED"
  elif [ "$1" -ge 50 ]; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"
  fi
}

# bar <pct> <width>
bar() {
  local pct=$1 width=$2 filled i full="" empty=""
  [ "$pct" -gt 100 ] && pct=100
  filled=$(( (pct * width + 50) / 100 ))
  for ((i = 0; i < width; i++)); do
    if [ "$i" -lt "$filled" ]; then full+="━"; else empty+="━"; fi
  done
  printf '%s%s%s%s%s' "$(level_color "$pct")" "$full" "$RST$DIM" "$empty" "$RST"
}

fmt_tokens() {
  local n=$1
  if [ "$n" -ge 1000000 ]; then
    local tenths=$((n % 1000000 / 100000))
    if [ "$tenths" -eq 0 ]; then printf '%dM' $((n / 1000000)); else printf '%d.%dM' $((n / 1000000)) "$tenths"; fi
  elif [ "$n" -ge 1000 ]; then
    printf '%dk' $(((n + 500) / 1000))
  else
    printf '%d' "$n"
  fi
}

# to_tokens <value>: "300000", "300k", "1M", or a bare 100-1000 meaning thousands; "auto" yields nothing
to_tokens() {
  local n mult
  case "$1" in
    *[kK]) n=${1%?}; mult=1000 ;;
    *[mM]) n=${1%?}; mult=1000000 ;;
    *)     n=$1;     mult=1 ;;
  esac
  case "$n" in '' | *[!0-9]*) return ;; esac
  [ "$mult" -eq 1 ] && [ "$n" -ge 100 ] && [ "$n" -le 1000 ] && mult=1000
  printf '%d' $((n * mult))
}

# until_reset <epoch>: time left as 42m, 2h14m or 3d4h
until_reset() {
  [ -z "$1" ] && return
  local s=$(( ${1%.*} - now ))
  [ "$s" -le 0 ] && return
  if [ "$s" -ge 86400 ]; then printf '%dd%dh' $((s / 86400)) $((s % 86400 / 3600))
  elif [ "$s" -ge 3600 ]; then printf '%dh%02dm' $((s / 3600)) $((s % 3600 / 60))
  else printf '%dm' $(((s + 59) / 60))
  fi
}

# meter <label> <pct-or-empty> <bar-width, 0 for none> [suffix]
meter() {
  local label=$1 raw=$2 width=$3 suffix=$4 pct
  if [ -z "$raw" ]; then
    printf '%s%s –%s' "$DIM" "$label" "$RST"
    return
  fi
  pct=$(printf '%.0f' "$raw")
  printf '%s%s%s ' "$DIM" "$label" "$RST"
  [ "$width" -gt 0 ] && printf '%s ' "$(bar "$pct" "$width")"
  printf '%s%s%%%s' "$(level_color "$pct")" "$pct" "$RST"
  [ -n "$suffix" ] && printf ' %s%s%s' "$DIM" "$suffix" "$RST"
}

out=""

# Repo and branch. The repo name comes from the shared .git dir so worktrees
# show the main repo's name instead of the worktree folder's.
if [ -n "$dir" ]; then
  common=$(git -C "$dir" --no-optional-locks rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  case "$common" in
    '')     repo="" ;;
    */.git) repo=$(basename "$(dirname "$common")") ;;
    *)      repo=$(basename "$common" .git) ;;
  esac
  [ -n "$repo" ] && out+="${BOLD}${repo}${RST}"
  branch=$(git -C "$dir" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null \
    || git -C "$dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    [ -n "$out" ] && out+=" "
    out+="${MAGENTA}⎇ ${BOLD}${branch}${RST}"
  fi
fi

# Pull request (clickable via OSC 8)
if [ -n "$pr_num" ]; then
  case "$pr_state" in
    approved)          pr_color=$GREEN;  pr_mark=" ✓" ;;
    changes_requested) pr_color=$RED;    pr_mark=" ✗" ;;
    pending)           pr_color=$YELLOW; pr_mark=" ●" ;;
    draft)             pr_color=$DIM;    pr_mark=" draft" ;;
    *)                 pr_color=$CYAN;   pr_mark="" ;;
  esac
  pr_text="#${pr_num}${pr_mark}"
  [ -n "$pr_url" ] && pr_text="${ESC}]8;;${pr_url}"$'\a'"${pr_text}${ESC}]8;;"$'\a'
  [ -n "$out" ] && out+="  "
  out+="${pr_color}${pr_text}${RST}"
fi

# Model, effort and fast mode
if [ -n "$model_name" ]; then
  [ -n "$out" ] && out+="$SEP"
  out+="${BLUE}${model_name#Claude }${RST}"
  [ -n "$effort" ] && out+=" ${DIM}·${RST} ${effort}"
  [ -n "$fast" ] && out+=" ${YELLOW}⚡${RST}"
fi

# Context, measured against the auto-compact window when one is set:
# env var first, then settings files from highest to lowest precedence.
compact=$(to_tokens "${CLAUDE_CODE_AUTO_COMPACT_WINDOW:-}")
if [ -z "$compact" ]; then
  root=${proj:-$dir}
  case "$(uname -s)" in
    Darwin) managed="/Library/Application Support/ClaudeCode/managed-settings.json" ;;
    *)      managed="/etc/claude-code/managed-settings.json" ;;
  esac
  files=()
  for f in "$managed" \
    ${root:+"$root/.claude/settings.local.json" "$root/.claude/settings.json"} \
    "$HOME/.claude/settings.json"; do
    [ -f "$f" ] && files+=("$f")
  done
  if [ ${#files[@]} -gt 0 ]; then
    compact=$(to_tokens "$(jq -rn --arg m "$model_id" '
      ($m | sub("\\[1m\\]$"; "") | sub("-[0-9]{8}$"; "")) as $key
      | first(inputs | (.modelSettings[$key].autoCompactWindow // .autoCompactWindow) | select(. != null)) // empty
    ' "${files[@]}" 2>/dev/null)")
  fi
fi
limit=$ctx_size
[ -n "$compact" ] && { [ -z "$limit" ] || [ "$compact" -lt "$limit" ]; } && limit=$compact

ctx_pct=""
ctx_suffix=""
if [ -n "$ctx_tok" ] && [ -n "$limit" ] && [ "$limit" -gt 0 ]; then
  ctx_pct=$(( (ctx_tok * 100 + limit / 2) / limit ))
  ctx_suffix="$(fmt_tokens "$ctx_tok")/$(fmt_tokens "$limit")"
fi
five_left=$(until_reset "$five_reset")
week_left=$(until_reset "$week_reset")

# meters <ctx-bar-width> <usage-bar-width>: context and subscription usage windows
meters() {
  meter "ctx" "$ctx_pct" "$1" "$ctx_suffix"
  # A cold cache means the next message re-processes the whole context.
  [ -n "$cache_cold" ] && printf ' %s❄ cold%s' "$CYAN" "$RST"
  printf '%s%s' "$SEP" "$(meter "5h" "$five_pct" "$2" "$five_left")"
  printf '%s%s' "$SEP" "$(meter "7d" "$week_pct" "$2" "$week_left")"
}

# Use the richest layout that fits: one line with bars, then two lines
# (where you are / how much room is left), shedding bars as space runs out.
full=$(meters 10 5)
ctx_only=$(meters 10 0)
bare=$(meters 0 0)
fits() { [ "$(vislen "$1")" -le "$max_width" ]; }

if [ -z "$out" ]; then
  for body in "$full" "$ctx_only" "$bare"; do fits "$body" && break; done
  printf '%s\n' "$body"
elif fits "$out$SEP$full"; then
  printf '%s\n' "$out$SEP$full"
elif fits "$out$SEP$ctx_only"; then
  printf '%s\n' "$out$SEP$ctx_only"
else
  for body in "$full" "$ctx_only" "$bare"; do fits "$body" && break; done
  printf '%s\n%s\n' "$out" "$body"
fi
