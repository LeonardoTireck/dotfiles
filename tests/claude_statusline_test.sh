#!/bin/sh

set -eu

TEST_DIR=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -P "$TEST_DIR/.." && pwd)
for required_command in stow git jq perl bash; do
  command -v "$required_command" >/dev/null 2>&1 || {
    printf 'claude status line test: %s is required\n' "$required_command" >&2
    exit 1
  }
done
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-claude-test.XXXXXX")
TEST_ROOT=$(CDPATH= cd -P "$TEST_ROOT" && pwd)
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

fail() {
  printf 'claude status line test: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  case "$1" in
    *"$2"*) : ;;
    *) fail "expected '$2' in '$1'" ;;
  esac
}

assert_not_contains() {
  case "$1" in
    *"$2"*) fail "unexpected '$2' in '$1'" ;;
    *) : ;;
  esac
}

deploy() {
  if ! HOME="$1" "$REPO_ROOT/install.sh" --claude >"$TEST_ROOT/install.log" 2>&1; then
    cat "$TEST_ROOT/install.log" >&2
    fail "Claude deployment into $1 failed"
  fi
}

# status_line <home> <dir> [extra-path]: plain-text output for a session in <dir>
status_line() {
  printf '{"workspace":{"current_dir":"%s"},"model":{"id":"claude-test","display_name":"Claude Test"},"context_window":{"context_window_size":1000000,"current_usage":{"input_tokens":30000}}}' "$2" \
    | HOME="$1" COLUMNS=200 PATH="${3:+$3:}$PATH" "$1/.claude/statusline.sh" \
    | perl -pe 's/\e\]8;;[^\a]*\a//g; s/\e\[[0-9;]*m//g'
}

# A fresh home must get a real ~/.claude, never a link into the repository.
fresh_home=$TEST_ROOT/fresh
mkdir -p "$fresh_home"
deploy "$fresh_home"
[ -d "$fresh_home/.claude" ] || fail '~/.claude was not created'
[ ! -L "$fresh_home/.claude" ] || fail '~/.claude was folded into a repository symlink'
[ -L "$fresh_home/.claude/statusline.sh" ] || fail 'statusline.sh was not linked'
case "$(readlink "$fresh_home/.claude/statusline.sh")" in
  *packages/claude/dot-claude/statusline.sh) : ;;
  *) fail 'statusline.sh does not point to the repository package' ;;
esac
[ -x "$fresh_home/.claude/statusline.sh" ] || fail 'statusline.sh is not executable'
[ "$(jq -r '.statusLine.command' "$fresh_home/.claude/settings.json")" = '~/.claude/statusline.sh' ] \
  || fail 'a fresh settings.json did not enable the status line'

# Simulation reports the settings change without making it.
simulated_home=$TEST_ROOT/simulated
mkdir -p "$simulated_home"
simulation=$(HOME="$simulated_home" "$REPO_ROOT/install.sh" --simulate --claude 2>&1) \
  || fail 'Claude simulation failed'
assert_contains "$simulation" "Would add statusLine to $simulated_home/.claude/settings.json"
[ ! -e "$simulated_home/.claude/settings.json" ] || fail 'simulation wrote settings.json'

# Existing settings keep every other key, and a second run changes nothing.
home=$TEST_ROOT/home
mkdir -p "$home/.claude"
printf '%s\n' '{"autoCompactWindow": 300000}' >"$home/.claude/settings.json"
deploy "$home"
[ -f "$home/.claude/settings.json" ] && [ ! -L "$home/.claude/settings.json" ] \
  || fail 'settings.json was replaced'
[ "$(jq -c '[.autoCompactWindow, .statusLine.command]' "$home/.claude/settings.json")" = '[300000,"~/.claude/statusline.sh"]' ] \
  || fail 'settings.json was not merged'
merged_settings=$(cat "$home/.claude/settings.json")
deploy "$home"
[ "$(cat "$home/.claude/settings.json")" = "$merged_settings" ] || fail 'a second run changed settings.json'

# A statusLine the user already chose is never replaced.
custom_home=$TEST_ROOT/custom
mkdir -p "$custom_home/.claude"
printf '%s\n' '{"statusLine": {"type": "command", "command": "my-line"}}' >"$custom_home/.claude/settings.json"
deploy "$custom_home"
[ "$(cat "$custom_home/.claude/settings.json")" = '{"statusLine": {"type": "command", "command": "my-line"}}' ] \
  || fail 'an existing statusLine was changed'

# Settings that are not a JSON object are left alone with a warning.
broken_home=$TEST_ROOT/broken
mkdir -p "$broken_home/.claude"
printf '%s\n' 'not json' >"$broken_home/.claude/settings.json"
deploy "$broken_home"
[ "$(cat "$broken_home/.claude/settings.json")" = 'not json' ] || fail 'invalid settings.json was changed'
assert_contains "$(cat "$TEST_ROOT/install.log")" 'is not a JSON object'
[ -L "$broken_home/.claude/statusline.sh" ] || fail 'statusline.sh was not linked next to invalid settings'

repo=$TEST_ROOT/sample-repo
mkdir -p "$repo/sub"
HOME="$home" git -C "$repo" init -q
HOME="$home" git -C "$repo" symbolic-ref HEAD refs/heads/feature
HOME="$home" git -C "$repo" -c user.name=test -c user.email=test@example.com commit -q --allow-empty -m init
HOME="$home" git -C "$repo" worktree add -q -b wt-branch "$TEST_ROOT/sample-repo.wt-branch"

output=$(status_line "$home" "$repo")
assert_contains "$output" 'sample-repo ⎇ feature'
assert_contains "$output" '10% 30k/300k'
assert_contains "$(status_line "$home" "$repo/sub")" 'sample-repo ⎇ feature'
assert_contains "$(status_line "$home" "$TEST_ROOT/sample-repo.wt-branch")" 'sample-repo ⎇ wt-branch'

outside=$(status_line "$home" "$TEST_ROOT/fresh")
assert_not_contains "$outside" '⎇'
assert_contains "$outside" 'Test │ ctx'

# The Linux branch picks its managed settings path and still reads user settings.
mkdir -p "$TEST_ROOT/bin"
printf '%s\n' '#!/bin/sh' 'printf "%s\n" Linux' >"$TEST_ROOT/bin/uname"
chmod +x "$TEST_ROOT/bin/uname"
linux_output=$(status_line "$home" "$repo" "$TEST_ROOT/bin")
assert_contains "$linux_output" 'sample-repo ⎇ feature'
assert_contains "$linux_output" '10% 30k/300k'

printf 'PASS Claude Code status line package\n'
