#!/bin/sh

set -eu

TEST_DIR=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -P "$TEST_DIR/.." && pwd)
ZSH_BIN=$(command -v zsh) || {
  printf 'cross-platform config test: zsh is required\n' >&2
  exit 1
}
GHOSTTY_BIN=$(command -v ghostty || :)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-platform-test.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

fail() {
  printf 'cross-platform config test: %s\n' "$1" >&2
  exit 1
}

assert_line() {
  if ! printf '%s\n' "$1" | grep -Fxq "$2"; then
    config_key=${2%% = *}
    actual_line=$(printf '%s\n' "$1" | grep -F "$config_key = " | head -n 1)
    fail "expected '$2', got '$actual_line'"
  fi
}

assert_no_line() {
  if printf '%s\n' "$1" | grep -Fxq "$2"; then
    fail "unexpected config line: $2"
  fi
}

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/mac/.config" "$TEST_ROOT/linux/.config"
printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$MYDOTFILES_TEST_PLATFORM"' > "$TEST_ROOT/bin/uname"
chmod +x "$TEST_ROOT/bin/uname"

# An existing Linux link must keep its settings immediately after a pull.
stow --dir="$REPO_ROOT/packages" --target="$TEST_ROOT/linux/.config" --dotfiles ghostty
# An older Mac installation can be migrated without touching the Linux package.
stow --dir="$REPO_ROOT/packages" --target="$TEST_ROOT/mac/.config" --dotfiles ghostty
stow --dir="$REPO_ROOT/packages" --target="$TEST_ROOT/mac/.config" --dotfiles --delete ghostty
linux_file=$(sed -n '1,$p' "$TEST_ROOT/linux/.config/ghostty/config")
assert_line "$linux_file" 'keybind = "super+shift+r=reload_config"'
assert_line "$linux_file" 'font-size = 13'
printf '%s\n' "$linux_file" | grep -Fq 'font-family = FiraCode Nerd Font Med' \
  || fail 'Linux Ghostty font changed'
assert_line "$linux_file" 'window-decoration = false'
if [ -n "$GHOSTTY_BIN" ]; then
  linked_linux_config=$(HOME="$TEST_ROOT/linux" XDG_CONFIG_HOME="$TEST_ROOT/linux/.config" \
    "$GHOSTTY_BIN" +show-config) || fail 'existing Linux link failed to load Ghostty'
  assert_line "$linked_linux_config" 'font-family = FiraCode Nerd Font Med'
fi
mkdir -p "$TEST_ROOT/linux/powerlevel10k" "$TEST_ROOT/linux/.cargo/bin" \
  "$TEST_ROOT/linux/.local/bin/Azure.Functions.Cli.linux-x64.4.7.0"
printf '%s\n' 'export MYDOTFILES_TEST_LINUX_THEME=loaded' \
  > "$TEST_ROOT/linux/powerlevel10k/powerlevel10k.zsh-theme"

for test_platform in Darwin Linux; do
  case "$test_platform" in
    Darwin) test_home=$TEST_ROOT/mac ;;
    Linux) test_home=$TEST_ROOT/linux ;;
  esac

  if ! HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" \
    MYDOTFILES_TEST_PLATFORM="$test_platform" PATH="$TEST_ROOT/bin:$PATH" \
    "$REPO_ROOT/install.sh" --zsh --ghostty; then
    fail "$test_platform deployment failed"
  fi

  [ -L "$test_home/.zshrc" ] || fail "$test_platform zshrc was not linked"
  [ -L "$test_home/.config/ghostty" ] || fail "$test_platform Ghostty config was not linked"

  if [ "$test_platform" = Darwin ]; then
    case "$(readlink "$test_home/.config/ghostty")" in
      *packages/ghostty-macos/ghostty) : ;;
      *) fail 'macOS Ghostty profile was not selected' ;;
    esac
    [ -r "$test_home/.config/ghostty/config.ghostty" ] \
      || fail 'macOS Ghostty config.ghostty was not linked'
    [ ! -e "$test_home/.config/ghostty/config" ] \
      || fail 'legacy Ghostty config was also linked on macOS'
    [ -r "$test_home/.config/ghostty/themes/Everforest Light Nvim" ] \
      || fail 'macOS Ghostty custom theme was not linked'
    [ ! -e "$test_home/Library/Application Support/com.mitchellh.ghostty/config.ghostty" ] \
      || fail 'macOS Ghostty config was placed in Library'
  else
    case "$(readlink "$test_home/.config/ghostty")" in
      *packages/ghostty/ghostty) : ;;
      *) fail 'Linux Ghostty profile changed' ;;
    esac
  fi

  if ! HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" \
    MYDOTFILES_ZSH_PLATFORM="$test_platform" "$ZSH_BIN" -f -c \
    'set -e; source "$HOME/.zshrc"; [[ "$EDITOR" == nvim ]]'; then
    fail "$test_platform Zsh startup failed"
  fi

  if [ "$test_platform" = Linux ]; then
    HOME="$test_home" PATH=/usr/bin:/bin MYDOTFILES_ZSH_PLATFORM=Linux "$ZSH_BIN" -f -c \
      'source "$HOME/.zshrc"; expected="$HOME/.opencode/bin:$HOME/.local/bin/Azure.Functions.Cli.linux-x64.4.7.0/:$HOME/.local/bin:$HOME/.cargo/bin:/usr/bin:/bin:/usr/local/go/bin"; [[ "$MYDOTFILES_TEST_LINUX_THEME" == loaded && "$PATH" == "$expected" ]]' \
      || fail 'Linux prompt or PATH differs from the previous profile'
  fi
done

if [ -n "$GHOSTTY_BIN" ]; then
  HOME="$TEST_ROOT/mac" XDG_CONFIG_HOME="$TEST_ROOT/mac/.config" \
    "$GHOSTTY_BIN" +validate-config \
    || fail 'macOS Ghostty config did not validate'
  mac_config=$(HOME="$TEST_ROOT/mac" XDG_CONFIG_HOME="$TEST_ROOT/mac/.config" \
    "$GHOSTTY_BIN" +show-config) \
    || fail 'macOS Ghostty config failed to load'

  assert_line "$mac_config" 'font-family = JetBrainsMono Nerd Font'
  assert_line "$mac_config" 'font-size = 20'
  assert_line "$mac_config" 'background-opacity = 0.98'
  HOME="$TEST_ROOT/linux" XDG_CONFIG_HOME="$TEST_ROOT/linux/.config" \
    "$GHOSTTY_BIN" +validate-config || fail 'Linux Ghostty config did not validate'
  linux_config=$(HOME="$TEST_ROOT/linux" XDG_CONFIG_HOME="$TEST_ROOT/linux/.config" \
    "$GHOSTTY_BIN" +show-config) || fail 'Linux Ghostty config failed to load'
  [ "$linked_linux_config" = "$linux_config" ] \
    || fail 'Linux Ghostty settings changed during installation'
  assert_line "$linux_config" 'font-family = FiraCode Nerd Font Med'
  assert_line "$linux_config" 'keybind = super+shift+r=reload_config'
  assert_no_line "$linux_config" 'font-size = 20'
  assert_no_line "$linux_config" 'background-opacity = 0.98'
  assert_no_line "$linux_config" 'window-width = 1640'
  assert_no_line "$linux_config" 'window-height = 510'
fi

printf 'PASS macOS and Linux Zsh and Ghostty profiles\n'
