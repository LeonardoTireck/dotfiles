#!/bin/sh

set -eu

TEST_DIR=$(CDPATH= cd -P "$(dirname "$0")" 2>/dev/null && pwd)
REPO_ROOT=$(CDPATH= cd -P "$TEST_DIR/.." 2>/dev/null && pwd)
CONFIG_FILE=$REPO_ROOT/packages/tmux/dot-tmux.conf
PLUGIN_ROOT=$REPO_ROOT/packages/tmux/dot-tmux/plugins

fail() {
  printf 'tmux external plugin test: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  assert_file=$1
  assert_text=$2
  grep -F "$assert_text" "$assert_file" >/dev/null 2>&1 || fail "expected '$assert_text' in $assert_file"
}

new_temp() {
  test_tmp=$(mktemp -d "${TMPDIR:-/tmp}/myDotFiles-tmux-test.XXXXXX") || fail 'could not create temporary directory'
  trap cleanup EXIT
}

cleanup() {
  if [ -n "${socket_path:-}" ]; then
    HOME="${tmux_home:-$test_tmp/home}" tmux -S "$socket_path" kill-server >/dev/null 2>&1 || :
  fi
  rm -rf "$test_tmp"
}

wait_for_path() {
  wait_path=$1
  wait_count=0
  while [ ! -e "$wait_path" ] && [ "$wait_count" -lt 60 ]; do
    sleep 0.1
    wait_count=$((wait_count + 1))
  done
  [ -e "$wait_path" ] || fail "timed out waiting for $wait_path"
}

test_no_vendored_plugin_sources() {
  [ ! -e "$PLUGIN_ROOT/tpm" ] || fail 'TPM source directory is vendored'
  [ ! -e "$PLUGIN_ROOT/tmux-resurrect" ] || fail 'tmux-resurrect source directory is vendored'
}

test_external_plugin_declarations() {
  plugin_count=$(grep -c '^set -g @plugin ' "$CONFIG_FILE")
  [ "$plugin_count" -eq 2 ] || fail "expected exactly two TPM plugin declarations, found $plugin_count"
  assert_contains "$CONFIG_FILE" "set -g @plugin 'tmux-plugins/tpm'"
  assert_contains "$CONFIG_FILE" "set -g @plugin 'tmux-plugins/tmux-resurrect'"
}

test_local_catppuccin_entrypoint() {
  [ -f "$PLUGIN_ROOT/catppuccin-tmux/catppuccin.tmux" ] || fail 'bundled Catppuccin entrypoint is missing'
  assert_contains "$CONFIG_FILE" "run '~/.tmux/plugins/catppuccin-tmux/catppuccin.tmux'"
  if grep -Eq '^set -g @plugin .*catppuccin' "$CONFIG_FILE"; then
    fail 'Catppuccin is still declared as a TPM plugin'
  fi
}

test_tpm_is_final_command() {
  last_command=$(awk 'NF && $1 !~ /^#/ { line = $0 } END { print line }' "$CONFIG_FILE")
  [ "$last_command" = "run '~/.tmux/plugins/tpm/tpm'" ] || fail 'TPM initialization is not the final tmux command'
}

test_stow_deploys_tmux_package() {
  new_temp
  tmux_home=$test_tmp/home
  mkdir -p "$tmux_home"
  if ! HOME="$tmux_home" "$REPO_ROOT/install.sh" --tmux >"$test_tmp/install.log" 2>&1; then
    cat "$test_tmp/install.log" >&2
    fail 'tmux Stow deployment failed'
  fi
  [ -L "$tmux_home/.tmux.conf" ] || fail '.tmux.conf was not deployed as a link'
  case "$(readlink "$tmux_home/.tmux.conf")" in
    *packages/tmux/dot-tmux.conf) : ;;
    *) fail '.tmux.conf does not point to the repository package' ;;
  esac
  [ -d "$tmux_home/.tmux" ] || fail '.tmux was not deployed as a directory'
  [ ! -L "$tmux_home/.tmux" ] || fail '.tmux was folded into a repository symlink'
  [ -L "$tmux_home/.tmux/plugins/catppuccin-tmux/catppuccin.tmux" ] || fail 'Catppuccin entrypoint was not Stow-linked'
}

test_stow_is_local_only() {
  new_temp
  forbidden_bin=$test_tmp/bin
  forbidden_log=$test_tmp/forbidden.log
  tmux_home=$test_tmp/home
  mkdir -p "$forbidden_bin" "$tmux_home"
  stow_path=$(command -v stow) || fail 'GNU Stow is required for this proof'
  ln -s "$stow_path" "$forbidden_bin/stow"
  for forbidden_command in git curl wget fetch brew apt apt-get dnf pacman apk npm pip pip3 cargo; do
    printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$0" >> "$MYDOTFILES_FORBIDDEN_LOG"' 'exit 97' >"$forbidden_bin/$forbidden_command"
    chmod +x "$forbidden_bin/$forbidden_command"
  done
  if ! HOME="$tmux_home" PATH="$forbidden_bin:/usr/bin:/bin" MYDOTFILES_FORBIDDEN_LOG="$forbidden_log" "$REPO_ROOT/install.sh" --tmux >"$test_tmp/install.log" 2>&1; then
    cat "$test_tmp/install.log" >&2
    fail 'local tmux deployment attempted a forbidden external command'
  fi
  [ ! -s "$forbidden_log" ] || fail 'a forbidden external command was invoked during deployment'
}

prepare_tmux_home() {
  tmux_home=$test_tmp/home
  mkdir -p "$tmux_home/.tmux/plugins/tpm"
  ln -s "$REPO_ROOT/packages/tmux/dot-tmux/plugins/catppuccin-tmux" "$tmux_home/.tmux/plugins/catppuccin-tmux"
  socket_path=$test_tmp/tmux.sock
}

test_tpm_runtime_controls() {
  new_temp
  prepare_tmux_home
  ready_marker=$test_tmp/tpm-ready
  tpm_script=$tmux_home/.tmux/plugins/tpm/tpm
  printf '%s\n' '#!/bin/sh' \
    "tmux bind-key -T prefix I run-shell \"touch '$test_tmp/prefix-i-fired'\"" \
    "touch '$ready_marker'" >"$tpm_script"
  chmod +x "$tpm_script"
  HOME="$tmux_home" tmux -S "$socket_path" -f "$CONFIG_FILE" new-session -d -s test
  wait_for_path "$ready_marker"
  key_list=$(HOME="$tmux_home" tmux -S "$socket_path" list-keys -T prefix)
  printf '%s\n' "$key_list" | grep -E 'prefix I[[:space:]]+run-shell' >/dev/null 2>&1 || fail 'TPM did not expose the prefix install binding'
}

test_prefix_i_installs_external_plugin() {
  new_temp
  prepare_tmux_home
  ready_marker=$test_tmp/tpm-ready
  checkout_dir=$tmux_home/.tmux/plugins/tmux-resurrect
  reload_marker=$test_tmp/tmux-reloaded
  tpm_script=$tmux_home/.tmux/plugins/tpm/tpm
  command -v python3 >/dev/null 2>&1 || fail 'python3 is required for the attached-client tmux proof'
  printf '%s\n' '#!/bin/sh' \
    "tmux bind-key -T prefix I run-shell \"mkdir -p '$checkout_dir'; touch '$checkout_dir/.checkout'; tmux source-file '$CONFIG_FILE'; printf '%s\\n' reload >> '$reload_marker'\"" \
    "touch '$ready_marker'" >"$tpm_script"
  chmod +x "$tpm_script"
  HOME="$tmux_home" tmux -S "$socket_path" -f "$CONFIG_FILE" new-session -d -s test
  wait_for_path "$ready_marker"
  HOME="$tmux_home" python3 - "$socket_path" "$checkout_dir/.checkout" "$reload_marker" <<'PY'
import os
import pty
import select
import signal
import sys
import time

socket_path, checkout_marker, reload_marker = sys.argv[1:]

def line_count(path):
    try:
        with open(path) as handle:
            return sum(1 for _ in handle)
    except FileNotFoundError:
        return 0

pid, fd = pty.fork()
if pid == 0:
    os.environ["TERM"] = "xterm-256color"
    os.execlp("tmux", "tmux", "-S", socket_path, "attach-session", "-t", "test")

try:
    time.sleep(0.5)
    os.write(fd, b"\x13I")
    deadline = time.time() + 5
    while time.time() < deadline and not os.path.exists(checkout_marker):
        ready, _, _ = select.select([fd], [], [], 0.1)
        if ready:
            try:
                os.read(fd, 4096)
            except OSError:
                break
    if not os.path.exists(checkout_marker):
        raise SystemExit("prefix + I did not create the external checkout")
    time.sleep(0.3)
    os.write(fd, b"\x13I")
    deadline = time.time() + 5
    while time.time() < deadline:
        if line_count(reload_marker) >= 2:
            break
        ready, _, _ = select.select([fd], [], [], 0.1)
        if ready:
            try:
                os.read(fd, 4096)
            except OSError:
                break
finally:
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        os.waitpid(pid, 0)
    except ChildProcessError:
        pass

if line_count(reload_marker) < 2:
    raise SystemExit("repeated prefix + I did not reload twice")
PY
  wait_for_path "$checkout_dir/.checkout"
  wait_for_path "$reload_marker"
  [ -d "$checkout_dir" ] || fail 'external tmux-resurrect checkout was not created'
  reload_count=$(wc -l <"$reload_marker" | tr -d ' ')
  [ "$reload_count" -eq 2 ] || fail "expected two reloads, found $reload_count"
  plugin_count=$(find "$tmux_home/.tmux/plugins" -mindepth 1 -maxdepth 1 -type d -name tmux-resurrect -print | wc -l | tr -d ' ')
  [ "$plugin_count" -eq 1 ] || fail "expected one tmux-resurrect checkout, found $plugin_count"
}

test_real_tpm_fetches_external_plugin() {
  new_temp
  tpm_source=${TPM_SOURCE:-${HOME:-}/.tmux/plugins/tpm}
  [ -x "$tpm_source/tpm" ] || fail "real TPM is required at $tpm_source for this integration proof"
  tmux_home=$test_tmp/home
  fixture_repo=$test_tmp/tmux-resurrect-source
  fake_bin=$test_tmp/bin
  git_log=$test_tmp/git.log
  mkdir -p "$tmux_home/.tmux/plugins" "$fixture_repo" "$fake_bin"
  cp -R "$tpm_source/." "$tmux_home/.tmux/plugins/tpm/"
  ln -s "$REPO_ROOT/packages/tmux/dot-tmux/plugins/catppuccin-tmux" "$tmux_home/.tmux/plugins/catppuccin-tmux"
  ln -s "$CONFIG_FILE" "$tmux_home/.tmux.conf"
  git -C "$fixture_repo" init -q
  printf '%s\n' local-fixture >"$fixture_repo/README.md"
  git -C "$fixture_repo" add README.md
  git -C "$fixture_repo" -c user.name=tmux-test -c user.email=tmux-test@example.com commit -qm fixture
  printf '%s\n' '#!/bin/sh' \
    "printf '%s\\n' \"\$*\" >> '$git_log'" \
    'case "$*" in' \
    "  *tmux-plugins/tmux-resurrect*) exec /usr/bin/git clone '$fixture_repo' tmux-resurrect ;;" \
    'esac' \
    'exec /usr/bin/git "$@"' >"$fake_bin/git"
  chmod +x "$fake_bin/git"
  socket_path=$test_tmp/tmux.sock
  PATH="$fake_bin:/usr/bin:/bin" HOME="$tmux_home" tmux -S "$socket_path" -f "$CONFIG_FILE" new-session -d -s test
  key_ready=0
  key_count=0
  while [ "$key_count" -lt 60 ]; do
    key_list=$(PATH="$fake_bin:/usr/bin:/bin" HOME="$tmux_home" tmux -S "$socket_path" list-keys -T prefix 2>/dev/null || :)
    if printf '%s\n' "$key_list" | grep -E 'prefix I[[:space:]]+run-shell' >/dev/null 2>&1; then
      key_ready=1
      break
    fi
    sleep 0.1
    key_count=$((key_count + 1))
  done
  [ "$key_ready" -eq 1 ] || fail 'real TPM did not expose the prefix install binding'
  checkout_marker=$tmux_home/.tmux/plugins/tmux-resurrect/.git/HEAD
  if ! PATH="$fake_bin:/usr/bin:/bin" HOME="$tmux_home" python3 - "$socket_path" "$checkout_marker" <<'PY'
import os
import pty
import select
import signal
import sys
import time

socket_path, checkout_marker = sys.argv[1:]
pid, fd = pty.fork()
if pid == 0:
    os.environ["TERM"] = "xterm-256color"
    os.execlp("tmux", "tmux", "-S", socket_path, "attach-session", "-t", "test")

try:
    time.sleep(0.5)
    os.write(fd, b"\x13I")
    deadline = time.time() + 10
    while time.time() < deadline and not os.path.exists(checkout_marker):
        ready, _, _ = select.select([fd], [], [], 0.1)
        if ready:
            try:
                os.read(fd, 4096)
            except OSError:
                break
finally:
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        os.waitpid(pid, 0)
    except ChildProcessError:
        pass

if not os.path.exists(checkout_marker):
    raise SystemExit("real TPM did not fetch the external plugin")
PY
  then
    cat "$git_log" >&2 2>/dev/null || :
    fail 'real TPM did not fetch the external plugin'
  fi
  [ -d "$tmux_home/.tmux/plugins/tmux-resurrect/.git" ] || fail 'real TPM checkout is missing its Git metadata'
  [ ! -e "$PLUGIN_ROOT/tmux-resurrect" ] || fail 'real TPM created a repository plugin copy'
}

test_deployment_is_idempotent() {
  new_temp
  tmux_home=$test_tmp/home
  mkdir -p "$tmux_home"
  HOME="$tmux_home" "$REPO_ROOT/install.sh" --tmux >"$test_tmp/first.log" 2>&1 || fail 'first tmux deployment failed'
  mkdir -p "$tmux_home/.tmux/plugins/tmux-resurrect"
  printf '%s\n' external-checkout >"$tmux_home/.tmux/plugins/tmux-resurrect/.checkout"
  HOME="$tmux_home" "$REPO_ROOT/install.sh" --tmux >"$test_tmp/second.log" 2>&1 || fail 'repeated tmux deployment failed'
  [ -f "$tmux_home/.tmux/plugins/tmux-resurrect/.checkout" ] || fail 'deployment removed the external plugin checkout'
  plugin_count=$(find "$tmux_home/.tmux/plugins" -mindepth 1 -maxdepth 1 -type d -print | wc -l | tr -d ' ')
  [ "$plugin_count" -eq 2 ] || fail "expected two plugin directories after retry, found $plugin_count"
}

test_stow_preserves_conflicts() {
  new_temp
  conflict_home=$test_tmp/file-conflict
  mkdir -p "$conflict_home"
  printf '%s\n' user-owned >"$conflict_home/.tmux.conf"
  if HOME="$conflict_home" "$REPO_ROOT/install.sh" --tmux >"$test_tmp/file-conflict.log" 2>&1; then
    fail 'Stow accepted a conflicting .tmux.conf'
  fi
  assert_contains "$conflict_home/.tmux.conf" user-owned
  assert_contains "$test_tmp/file-conflict.log" 'conflicts'

  nested_home=$test_tmp/nested-conflict
  mkdir -p "$nested_home/.tmux/plugins/catppuccin-tmux"
  printf '%s\n' user-owned >"$nested_home/.tmux/plugins/catppuccin-tmux/catppuccin.tmux"
  if HOME="$nested_home" "$REPO_ROOT/install.sh" --tmux >"$test_tmp/nested-conflict.log" 2>&1; then
    fail 'Stow accepted a conflicting Catppuccin entrypoint'
  fi
  assert_contains "$nested_home/.tmux/plugins/catppuccin-tmux/catppuccin.tmux" user-owned
  assert_contains "$test_tmp/nested-conflict.log" 'conflicts'
}

test_plugin_removal_preserves_external_checkout() {
  new_temp
  tmux_home=$test_tmp/home
  copy_root=$test_tmp/repo-copy
  mkdir -p "$tmux_home" "$copy_root/packages/tmux"
  cp "$REPO_ROOT/install.sh" "$copy_root/install.sh"
  cp -R "$REPO_ROOT/packages/tmux/." "$copy_root/packages/tmux/"
  HOME="$tmux_home" "$copy_root/install.sh" --tmux >"$test_tmp/initial.log" 2>&1 || fail 'initial tmux deployment failed'
  mkdir -p "$tmux_home/.tmux/plugins/tmux-resurrect"
  printf '%s\n' external-checkout >"$tmux_home/.tmux/plugins/tmux-resurrect/.checkout"
  grep -v "tmux-plugins/tmux-resurrect" "$copy_root/packages/tmux/dot-tmux.conf" >"$test_tmp/dot-tmux.conf"
  mv "$test_tmp/dot-tmux.conf" "$copy_root/packages/tmux/dot-tmux.conf"
  HOME="$tmux_home" "$copy_root/install.sh" --tmux >"$test_tmp/removed-plugin.log" 2>&1 || fail 'deployment with the plugin removed failed'
  assert_contains "$tmux_home/.tmux/plugins/tmux-resurrect/.checkout" external-checkout
}

run_test() {
  case "$1" in
    no_vendored_plugin_sources) test_no_vendored_plugin_sources ;;
    external_plugin_declarations) test_external_plugin_declarations ;;
    local_catppuccin_entrypoint) test_local_catppuccin_entrypoint ;;
    tpm_is_final_command) test_tpm_is_final_command ;;
    stow_deploys_tmux_package) test_stow_deploys_tmux_package ;;
    stow_is_local_only) test_stow_is_local_only ;;
    tpm_runtime_controls) test_tpm_runtime_controls ;;
    prefix_i_installs_external_plugin) test_prefix_i_installs_external_plugin ;;
    real_tpm_fetches_external_plugin) test_real_tpm_fetches_external_plugin ;;
    deployment_is_idempotent) test_deployment_is_idempotent ;;
    stow_preserves_conflicts) test_stow_preserves_conflicts ;;
    plugin_removal_preserves_external_checkout) test_plugin_removal_preserves_external_checkout ;;
    all)
      for test_name in \
        no_vendored_plugin_sources \
        external_plugin_declarations \
        local_catppuccin_entrypoint \
        tpm_is_final_command \
        stow_deploys_tmux_package \
        stow_is_local_only \
        tpm_runtime_controls \
        prefix_i_installs_external_plugin \
        real_tpm_fetches_external_plugin \
        deployment_is_idempotent \
        stow_preserves_conflicts \
        plugin_removal_preserves_external_checkout; do
        run_test "$test_name"
      done
      ;;
    *) fail "unknown test: $1" ;;
  esac
  printf 'PASS %s\n' "$1"
}

[ "$#" -eq 1 ] || fail 'expected one named test'
run_test "$1"
