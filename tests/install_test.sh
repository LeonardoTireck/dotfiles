#!/bin/sh

set -u

PROJECT_ROOT=$(CDPATH= cd -P "$(dirname "$0")/.." && pwd)
INSTALLER="$PROJECT_ROOT/install.sh"
ORIGINAL_PATH=$PATH
TEST_ROOT=${TMPDIR:-/tmp}/myDotFiles-install-tests.$$
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$TEST_ROOT"
}

trap cleanup EXIT HUP INT TERM
mkdir -p "$TEST_ROOT"

fail() {
  printf '  %s\n' "$1" >&2
  return 1
}

assert_file() {
  if [ ! -f "$1" ]; then
    fail "expected file: $1"
  fi
}

assert_dir() {
  if [ ! -d "$1" ]; then
    fail "expected directory: $1"
  fi
}

assert_not_exists() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    fail "expected path to be absent: $1"
  fi
}

assert_same_file() {
  if ! cmp -s "$1" "$2"; then
    fail "files differ: $1 and $2"
  fi
}

assert_text_contains() {
  case $1 in
    *"$2"*) ;;
    *) fail "expected text to contain [$2]";;
  esac
}

assert_equal() {
  if [ "$1" != "$2" ]; then
    fail "expected [$1], got [$2]"
  fi
}

new_case() {
  CASE_NAME=$1
  CASE_DIR="$TEST_ROOT/$CASE_NAME"
  TEST_HOME="$CASE_DIR/home"
  TEST_CONFIG="$CASE_DIR/config"
  TEST_STATE="$CASE_DIR/state"
  INSTALLER_UNDER_TEST=$INSTALLER
  mkdir -p "$TEST_HOME"
}

run_installer() {
  (
    cd "$CASE_DIR" || exit 1
    HOME="$TEST_HOME" XDG_CONFIG_HOME="$TEST_CONFIG" XDG_STATE_HOME="$TEST_STATE" \
      "$INSTALLER_UNDER_TEST" "$@"
  )
}

run_installer_fallback() {
  (
    cd "$CASE_DIR" || exit 1
    HOME="$TEST_HOME" XDG_CONFIG_HOME= XDG_STATE_HOME= \
      "$INSTALLER_UNDER_TEST" "$@"
  )
}

run_installer_with_path() {
  path_value=$1
  shift
  (
    cd "$CASE_DIR" || exit 1
    HOME="$TEST_HOME" XDG_CONFIG_HOME="$TEST_CONFIG" XDG_STATE_HOME="$TEST_STATE" \
      PATH="$path_value" "$INSTALLER_UNDER_TEST" "$@"
  )
}

backup_root() {
  printf '%s/myDotFiles/backups' "$TEST_STATE"
}

assert_no_other_groups() {
  assert_not_exists "$TEST_HOME/.tmux.conf" || return 1
  assert_not_exists "$TEST_HOME/.tmux" || return 1
  assert_not_exists "$TEST_CONFIG/ghostty" || return 1
  assert_not_exists "$TEST_CONFIG/herdr" || return 1
  assert_not_exists "$TEST_CONFIG/nvim" || return 1
  assert_not_exists "$TEST_HOME/github" || return 1
}

make_minimal_herdr_fixture() {
  FIXTURE_DIR=$CASE_DIR/repository
  mkdir -p "$FIXTURE_DIR/herdr"
  cp "$INSTALLER" "$FIXTURE_DIR/install.sh"
  chmod +x "$FIXTURE_DIR/install.sh"
  INSTALLER_UNDER_TEST=$FIXTURE_DIR/install.sh
}

snapshot_manifest() {
  snapshot_root=$1
  (
    cd "$snapshot_root" || exit 1
    find . -type f -print | sort
  )
}

assert_snapshot_tree() {
  expected_root=$1
  actual_root=$2
  expected_manifest_file=$CASE_DIR/.expected-manifest
  actual_manifest_file=$CASE_DIR/.actual-manifest
  snapshot_manifest "$expected_root" > "$expected_manifest_file"
  (cd "$actual_root" && find . -type f -print | sort) > "$actual_manifest_file"
  expected_manifest=$(sed -n '1,10000p' "$expected_manifest_file")
  actual_manifest=$(sed -n '1,10000p' "$actual_manifest_file")
  assert_equal "$expected_manifest" "$actual_manifest" || return 1
  while IFS= read -r relative; do
    [ -n "$relative" ] || continue
    assert_same_file "$expected_root/$relative" "$actual_root/$relative" || return 1
  done < "$expected_manifest_file"
}

test_default_install() {
  new_case default
  run_installer || return 1

  assert_same_file "$PROJECT_ROOT/term/.zshrc" "$TEST_HOME/.zshrc" || return 1
  assert_same_file "$PROJECT_ROOT/.tmux/.tmux.conf" "$TEST_HOME/.tmux.conf" || return 1
  assert_dir "$TEST_HOME/.tmux/plugins/catppuccin-tmux" || return 1
  assert_same_file \
    "$PROJECT_ROOT/.tmux/plugins/catppuccin-tmux/catppuccin-everforest-light.tmuxtheme" \
    "$TEST_HOME/.tmux/plugins/catppuccin-tmux/catppuccin-everforest-light.tmuxtheme" || return 1
  assert_same_file "$PROJECT_ROOT/ghostty/config" "$TEST_CONFIG/ghostty/config" || return 1
  assert_same_file "$PROJECT_ROOT/ghostty/themes/Everforest Light Nvim" \
    "$TEST_CONFIG/ghostty/themes/Everforest Light Nvim" || return 1
  assert_same_file "$PROJECT_ROOT/herdr/config.toml" "$TEST_CONFIG/herdr/config.toml" || return 1
  assert_same_file "$PROJECT_ROOT/nvim/lazyvim.json" "$TEST_CONFIG/nvim/lazyvim.json" || return 1
  assert_not_exists "$TEST_HOME/github" || return 1
  assert_not_exists "$TEST_HOME/github/github-recovery-codes.txt" || return 1
}

test_selective_zsh() {
  new_case selective-zsh
  run_installer --zsh || return 1
  assert_same_file "$PROJECT_ROOT/term/.zshrc" "$TEST_HOME/.zshrc" || return 1
  assert_no_other_groups
}

test_selective_tmux() {
  new_case selective-tmux
  run_installer --tmux || return 1
  assert_same_file "$PROJECT_ROOT/.tmux/.tmux.conf" "$TEST_HOME/.tmux.conf" || return 1
  assert_dir "$TEST_HOME/.tmux/plugins/catppuccin-tmux" || return 1
  assert_same_file "$PROJECT_ROOT/.tmux/plugins/catppuccin-tmux/catppuccin.tmux" \
    "$TEST_HOME/.tmux/plugins/catppuccin-tmux/catppuccin.tmux" || return 1
  assert_not_exists "$TEST_HOME/.zshrc" || return 1
  assert_not_exists "$TEST_CONFIG/ghostty" || return 1
  assert_not_exists "$TEST_CONFIG/herdr" || return 1
  assert_not_exists "$TEST_CONFIG/nvim" || return 1
  assert_not_exists "$TEST_HOME/github" || return 1
}

test_selective_ghostty() {
  new_case selective-ghostty
  run_installer --ghostty || return 1
  assert_same_file "$PROJECT_ROOT/ghostty/config" "$TEST_CONFIG/ghostty/config" || return 1
  assert_same_file "$PROJECT_ROOT/ghostty/themes/Everforest Light Nvim" \
    "$TEST_CONFIG/ghostty/themes/Everforest Light Nvim" || return 1
  assert_not_exists "$TEST_HOME/.zshrc" || return 1
  assert_not_exists "$TEST_HOME/.tmux.conf" || return 1
  assert_not_exists "$TEST_HOME/.tmux" || return 1
  assert_not_exists "$TEST_CONFIG/herdr" || return 1
  assert_not_exists "$TEST_CONFIG/nvim" || return 1
  assert_not_exists "$TEST_HOME/github" || return 1
}

test_selective_herdr() {
  new_case selective-herdr
  run_installer --herdr || return 1
  assert_same_file "$PROJECT_ROOT/herdr/config.toml" "$TEST_CONFIG/herdr/config.toml" || return 1
  assert_not_exists "$TEST_HOME/.zshrc" || return 1
  assert_not_exists "$TEST_HOME/.tmux.conf" || return 1
  assert_not_exists "$TEST_HOME/.tmux" || return 1
  assert_not_exists "$TEST_CONFIG/ghostty" || return 1
  assert_not_exists "$TEST_CONFIG/nvim" || return 1
  assert_not_exists "$TEST_HOME/github" || return 1
}

test_selective_nvim() {
  new_case selective-nvim
  run_installer --nvim || return 1
  assert_snapshot_tree "$PROJECT_ROOT/nvim" "$TEST_CONFIG/nvim" || return 1
  assert_not_exists "$TEST_HOME/.zshrc" || return 1
  assert_not_exists "$TEST_HOME/.tmux.conf" || return 1
  assert_not_exists "$TEST_HOME/.tmux" || return 1
  assert_not_exists "$TEST_CONFIG/ghostty" || return 1
  assert_not_exists "$TEST_CONFIG/herdr" || return 1
  assert_not_exists "$TEST_HOME/github" || return 1
}

test_combined_repeated_flags() {
  new_case combined-repeated
  run_installer --zsh --ghostty --zsh --ghostty || return 1
  assert_file "$TEST_HOME/.zshrc" || return 1
  assert_dir "$TEST_CONFIG/ghostty" || return 1
  assert_not_exists "$TEST_HOME/.tmux.conf" || return 1
  assert_not_exists "$TEST_HOME/.tmux" || return 1
  assert_not_exists "$TEST_CONFIG/herdr" || return 1
  assert_not_exists "$TEST_CONFIG/nvim" || return 1
  assert_not_exists "$TEST_HOME/github" || return 1
}

test_parent_creation_and_fallbacks() {
  new_case explicit-parents
  run_installer --tmux --ghostty --herdr || return 1
  assert_dir "$TEST_HOME/.tmux/plugins" || return 1
  assert_dir "$TEST_CONFIG/ghostty/themes" || return 1
  assert_dir "$TEST_CONFIG/herdr" || return 1

  new_case fallback-parents
  run_installer_fallback --herdr || return 1
  assert_file "$TEST_HOME/.config/herdr/config.toml" || return 1
  assert_dir "$TEST_HOME/.local/state/myDotFiles/backups" || return 1
}

test_backup_file_directory_symlink() {
  new_case backup-file
  printf 'old zsh configuration\n' > "$TEST_HOME/.zshrc"
  run_installer --zsh || return 1
  backup_file=$(find "$(backup_root)" -type f -path '*/zsh/.zshrc' -print | sed -n '1p')
  assert_file "$backup_file" || return 1
  grep -Fq 'old zsh configuration' "$backup_file" || return 1
  assert_same_file "$PROJECT_ROOT/term/.zshrc" "$TEST_HOME/.zshrc" || return 1

  new_case backup-directory
  mkdir -p "$TEST_HOME/.tmux/plugins/catppuccin-tmux"
  printf 'old plugin\n' > "$TEST_HOME/.tmux/plugins/catppuccin-tmux/marker"
  run_installer --tmux || return 1
  backup_marker=$(find "$(backup_root)" -type f -path '*/tmux/catppuccin-tmux/marker' -print | sed -n '1p')
  assert_file "$backup_marker" || return 1
  grep -Fq 'old plugin' "$backup_marker" || return 1
  assert_file "$TEST_HOME/.tmux/plugins/catppuccin-tmux/catppuccin.tmux" || return 1

  new_case backup-symlink
  symlink_target=$CASE_DIR/original-zsh
  printf 'symlink target\n' > "$symlink_target"
  ln -s "$symlink_target" "$TEST_HOME/.zshrc"
  run_installer --zsh || return 1
  if [ -L "$TEST_HOME/.zshrc" ]; then
    fail 'replacement must not remain a symlink' || return 1
  fi
  backup_link=$(find "$(backup_root)" -type l -path '*/zsh/.zshrc' -print | sed -n '1p')
  if [ ! -L "$backup_link" ]; then
    fail 'expected the original symlink in the backup' || return 1
  fi
  assert_equal "$symlink_target" "$(readlink "$backup_link")" || return 1
}

test_missing_source_preflight() {
  new_case missing-source
  make_minimal_herdr_fixture
  mkdir -p "$TEST_CONFIG/herdr"
  printf 'keep me\n' > "$TEST_CONFIG/herdr/config.toml"
  if run_installer --herdr; then
    fail 'missing source should fail' || return 1
  fi
  grep -Fq 'keep me' "$TEST_CONFIG/herdr/config.toml" || return 1
  assert_not_exists "$TEST_STATE/myDotFiles/backups" || return 1
}

test_unreadable_source_preflight() {
  new_case unreadable-source
  make_minimal_herdr_fixture
  printf 'unreadable\n' > "$CASE_DIR/repository/herdr/config.toml"
  chmod 000 "$CASE_DIR/repository/herdr/config.toml"
  mkdir -p "$TEST_CONFIG/herdr"
  printf 'keep me\n' > "$TEST_CONFIG/herdr/config.toml"
  if run_installer --herdr; then
    chmod 600 "$CASE_DIR/repository/herdr/config.toml"
    fail 'unreadable source should fail' || return 1
  fi
  chmod 600 "$CASE_DIR/repository/herdr/config.toml"
  grep -Fq 'keep me' "$TEST_CONFIG/herdr/config.toml" || return 1
  assert_not_exists "$TEST_STATE/myDotFiles/backups" || return 1
}

test_restore_after_copy_failure() {
  new_case restore-copy-failure
  printf 'original destination\n' > "$TEST_HOME/.zshrc"
  fake_bin=$CASE_DIR/bin
  mkdir -p "$fake_bin"
  printf '#!/bin/sh\nfor argument do destination=$argument; done\nprintf partial > "$destination"\nexit 97\n' \
    > "$fake_bin/cp"
  chmod +x "$fake_bin/cp"
  if run_installer_with_path "$fake_bin:$ORIGINAL_PATH" --zsh; then
    fail 'copy failure should fail the installation' || return 1
  fi
  grep -Fq 'original destination' "$TEST_HOME/.zshrc" || return 1
  if grep -Fq 'partial' "$TEST_HOME/.zshrc"; then
    fail 'partial replacement must be removed before restoration' || return 1
  fi
}

test_zsh_portability() {
  if grep -Fq '/home/leonardotireck/' "$PROJECT_ROOT/term/.zshrc"; then
    fail 'Zsh configuration contains the old hard-coded home path' || return 1
  fi
  grep -Fq 'export PATH="$HOME/.opencode/bin:$PATH"' "$PROJECT_ROOT/term/.zshrc" || return 1
  grep -Fq 'alias reload="source ~/.zshrc"' "$PROJECT_ROOT/term/.zshrc" || return 1
  grep -Fq 'export NVM_DIR="$HOME/.nvm"' "$PROJECT_ROOT/term/.zshrc" || return 1
}

test_zsh_optional_sources() {
  grep -Fq 'if [[ -r "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]' \
    "$PROJECT_ROOT/term/.zshrc" || return 1
  grep -Fq 'if [[ -r "$HOME/.local/share/powerlevel10k/powerlevel10k.zsh-theme" ]]' \
    "$PROJECT_ROOT/term/.zshrc" || return 1
  grep -Fq 'if [[ -r "$HOME/.p10k.zsh" ]]' "$PROJECT_ROOT/term/.zshrc" || return 1
}

test_rerun_creates_new_backup() {
  new_case rerun
  printf 'first zsh destination\n' > "$TEST_HOME/.zshrc"
  printf 'first tmux destination\n' > "$TEST_HOME/.tmux.conf"
  mkdir -p "$TEST_HOME/.tmux/plugins/catppuccin-tmux"
  printf 'first tmux plugin\n' > "$TEST_HOME/.tmux/plugins/catppuccin-tmux/marker"
  mkdir -p "$TEST_CONFIG/ghostty/themes" "$TEST_CONFIG/herdr" "$TEST_CONFIG/nvim"
  printf 'first ghostty config\n' > "$TEST_CONFIG/ghostty/config"
  printf 'first ghostty theme\n' > "$TEST_CONFIG/ghostty/themes/old-theme"
  printf 'first herdr config\n' > "$TEST_CONFIG/herdr/config.toml"
  printf 'first nvim config\n' > "$TEST_CONFIG/nvim/old.lua"
  run_installer || return 1
  run_installer || return 1
  assert_same_file "$PROJECT_ROOT/term/.zshrc" "$TEST_HOME/.zshrc" || return 1
  assert_same_file "$PROJECT_ROOT/.tmux/.tmux.conf" "$TEST_HOME/.tmux.conf" || return 1
  assert_snapshot_tree "$PROJECT_ROOT/.tmux/plugins/catppuccin-tmux" \
    "$TEST_HOME/.tmux/plugins/catppuccin-tmux" || return 1
  assert_same_file "$PROJECT_ROOT/ghostty/config" "$TEST_CONFIG/ghostty/config" || return 1
  assert_snapshot_tree "$PROJECT_ROOT/ghostty/themes" "$TEST_CONFIG/ghostty/themes" || return 1
  assert_same_file "$PROJECT_ROOT/herdr/config.toml" "$TEST_CONFIG/herdr/config.toml" || return 1
  assert_snapshot_tree "$PROJECT_ROOT/nvim" "$TEST_CONFIG/nvim" || return 1
  for backup_path in \
    '*/zsh/.zshrc' \
    '*/tmux/.tmux.conf' \
    '*/tmux/catppuccin-tmux' \
    '*/ghostty/config' \
    '*/ghostty/themes' \
    '*/herdr/config.toml' \
    '*/nvim/nvim'; do
    backup_count=$(find "$(backup_root)" -path "$(backup_root)/$backup_path" -print | wc -l | tr -d ' ')
    assert_equal 2 "$backup_count" || return 1
  done
}

test_local_only_installer() {
  new_case local-only
  fake_bin=$CASE_DIR/bin
  mkdir -p "$fake_bin"
  for forbidden in curl wget git brew apt apt-get dnf yum pacman npm pip cargo gem; do
    printf '#!/bin/sh\nprintf "forbidden command invoked: %s\\n" "$0" >&2\nexit 98\n' \
      "$forbidden" > "$fake_bin/$forbidden"
    chmod +x "$fake_bin/$forbidden"
  done
  run_installer_with_path "$fake_bin:$ORIGINAL_PATH" --zsh || return 1
  assert_file "$TEST_HOME/.zshrc" || return 1
  if grep -Eq '(^|[[:space:];&|()])(curl|wget|git|brew|apt-get|apt|dnf|yum|pacman|npm|pip|cargo|gem)([[:space:]]|$)' \
    "$INSTALLER"; then
    fail 'installer contains a forbidden external command' || return 1
  fi
}

test_help_is_read_only() {
  new_case help
  printf 'keep help destination\n' > "$TEST_HOME/.zshrc"
  if ! help_output=$(run_installer --help 2>&1); then
    fail '--help should exit zero' || return 1
  fi
  assert_text_contains "$help_output" 'Without flags, all supported groups are installed' || return 1
  assert_text_contains "$help_output" '--zsh' || return 1
  assert_text_contains "$help_output" '--tmux' || return 1
  assert_text_contains "$help_output" '--ghostty' || return 1
  assert_text_contains "$help_output" '--herdr' || return 1
  assert_text_contains "$help_output" '--nvim' || return 1
  grep -Fq 'keep help destination' "$TEST_HOME/.zshrc" || return 1
  assert_not_exists "$TEST_STATE/myDotFiles/backups" || return 1
}

test_invalid_arguments_are_read_only() {
  new_case invalid
  printf 'keep invalid destination\n' > "$TEST_HOME/.zshrc"
  if run_installer --unknown > "$CASE_DIR/unknown.out" 2>&1; then
    fail 'unknown option should fail' || return 1
  else
    status=$?
  fi
  assert_equal 2 "$status" || return 1
  assert_text_contains "$(sed -n '1,40p' "$CASE_DIR/unknown.out")" 'Usage:' || return 1
  assert_text_contains "$(sed -n '1,40p' "$CASE_DIR/unknown.out")" 'unknown option' || return 1
  grep -Fq 'keep invalid destination' "$TEST_HOME/.zshrc" || return 1

  if run_installer positional > "$CASE_DIR/positional.out" 2>&1; then
    fail 'positional argument should fail' || return 1
  else
    status=$?
  fi
  assert_equal 2 "$status" || return 1
  assert_text_contains "$(sed -n '1,40p' "$CASE_DIR/positional.out")" 'Usage:' || return 1
  assert_text_contains "$(sed -n '1,40p' "$CASE_DIR/positional.out")" 'unexpected positional argument' || return 1
  grep -Fq 'keep invalid destination' "$TEST_HOME/.zshrc" || return 1
  assert_not_exists "$TEST_STATE/myDotFiles/backups" || return 1
}

ALL_TESTS="test_default_install
test_selective_zsh
test_selective_tmux
test_selective_ghostty
test_selective_herdr
test_selective_nvim
test_combined_repeated_flags
test_parent_creation_and_fallbacks
test_backup_file_directory_symlink
test_missing_source_preflight
test_unreadable_source_preflight
test_restore_after_copy_failure
test_zsh_portability
test_zsh_optional_sources
test_rerun_creates_new_backup
test_local_only_installer
test_help_is_read_only
test_invalid_arguments_are_read_only"

if [ "$#" -eq 0 ]; then
  set -- $ALL_TESTS
fi

for test_name do
  case $test_name in
    test_default_install|test_selective_zsh|test_selective_tmux|test_selective_ghostty|\
    test_selective_herdr|test_selective_nvim|test_combined_repeated_flags|\
    test_parent_creation_and_fallbacks|test_backup_file_directory_symlink|\
    test_missing_source_preflight|test_unreadable_source_preflight|\
    test_restore_after_copy_failure|test_zsh_portability|test_zsh_optional_sources|\
    test_rerun_creates_new_backup|test_local_only_installer|test_help_is_read_only|\
    test_invalid_arguments_are_read_only)
      if "$test_name"; then
        PASS_COUNT=$((PASS_COUNT + 1))
        printf 'PASS %s\n' "$test_name"
      else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        printf 'FAIL %s\n' "$test_name" >&2
      fi
      ;;
    *)
      printf 'FAIL unknown test: %s\n' "$test_name" >&2
      FAIL_COUNT=$((FAIL_COUNT + 1))
      ;;
  esac
done

printf '%s passed, %s failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
