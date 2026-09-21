#!/bin/sh

set -eu

TEST_DIR=$(CDPATH= cd -P "$(dirname "$0")" 2>/dev/null && pwd)
REPO_ROOT=$(CDPATH= cd -P "$TEST_DIR/.." 2>/dev/null && pwd)
README_FILE=$REPO_ROOT/README.md

fail() {
  printf 'tmux bootstrap documentation test: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  assert_text=$1
  normalized_readme=$(tr '\n' ' ' <"$README_FILE" | sed 's/[[:space:]][[:space:]]*/ /g')
  case "$normalized_readme" in
    *"$assert_text"*) : ;;
    *) fail "expected '$assert_text' in README.md" ;;
  esac
}

line_number() {
  line_text=$1
  line_value=$(grep -n -F "$line_text" "$README_FILE" | head -n 1 | cut -d: -f1) || fail "missing '$line_text' in README.md"
  printf '%s\n' "$line_value"
}

test_tpm_prerequisite_order() {
  clone_line=$(line_number 'git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"')
  deploy_line=$(line_number './install.sh --tmux')
  [ "$clone_line" -lt "$deploy_line" ] || fail 'TPM installation is not documented before tmux deployment'
  assert_contains 'before starting or reloading tmux'
}

test_stow_conflict_order() {
  conflict_line=$(line_number 'Inspect '\''$HOME/.tmux.conf'\'' and '\''$HOME/.tmux/'\'' for user-owned files')
  deploy_line=$(line_number './install.sh --tmux')
  [ "$conflict_line" -lt "$deploy_line" ] || fail 'Stow conflict guidance is not documented before deployment'
  assert_contains 'Back up or explicitly migrate those files before continuing'
}

test_plugin_install_step() {
  assert_contains 'prefix + I'
  assert_contains "'tmux-plugins/tmux-resurrect'"
  assert_contains "'\$HOME/.tmux/plugins/'"
  assert_contains 'reloads the tmux environment'
}

test_missing_tpm_is_prerequisite() {
  assert_contains "'install.sh' does not install TPM"
  assert_contains 'TPM is a separate prerequisite'
  assert_contains 'Skip this command if that checkout already exists'
}

test_ownership_boundary_is_documented() {
  assert_contains 'TPM and upstream plugins are external to this repository'
  assert_contains "repository-owned Catppuccin files"
  assert_contains 'Catppuccin is already loaded from the Stow-managed local entrypoint'
  assert_contains 'it is not listed as a TPM plugin'
}

run_test() {
  case "$1" in
    tpm_prerequisite_order) test_tpm_prerequisite_order ;;
    stow_conflict_order) test_stow_conflict_order ;;
    plugin_install_step) test_plugin_install_step ;;
    missing_tpm_is_prerequisite) test_missing_tpm_is_prerequisite ;;
    ownership_boundary_is_documented) test_ownership_boundary_is_documented ;;
    all)
      for test_name in \
        tpm_prerequisite_order \
        stow_conflict_order \
        plugin_install_step \
        missing_tpm_is_prerequisite \
        ownership_boundary_is_documented; do
        run_test "$test_name"
      done
      ;;
    *) fail "unknown test: $1" ;;
  esac
  printf 'PASS %s\n' "$1"
}

[ "$#" -eq 1 ] || fail 'expected one named test'
run_test "$1"
