#!/bin/sh

set -u

usage() {
  cat <<EOF
Usage: $(basename "$0") [--simulate] [--zsh] [--tmux] [--ghostty] [--herdr] [--nvim] [--claude]

Without selectors, all supported groups are deployed: zsh, tmux, ghostty, herdr, nvim, and claude.
Selectors may be combined or repeated. Deployment creates symlinks through GNU Stow.

Options:
  --simulate  Show planned Stow operations without changing the filesystem.
  --zsh       Deploy the Zsh configuration and prompt configuration.
  --tmux      Deploy tmux configuration and repository-owned Catppuccin plugin.
  --ghostty   Deploy Ghostty configuration and themes.
  --herdr     Deploy Herdr configuration.
  --nvim      Deploy the Neovim configuration.
  --claude    Deploy the Claude Code status line script and enable it in settings.json.
  --help      Show this help text without changing any destination.
EOF
}

fail() {
  printf 'install.sh: %s\n' "$1" >&2
  return 1
}

SCRIPT_DIR=$(CDPATH= cd -P "$(dirname "$0")" 2>/dev/null && pwd) || {
  printf 'install.sh: unable to resolve repository root\n' >&2
  exit 1
}
REPO_ROOT=$SCRIPT_DIR

selected_zsh=0
selected_tmux=0
selected_ghostty=0
selected_herdr=0
selected_nvim=0
selected_claude=0
selection_count=0
simulate=0

for argument; do
  case $argument in
  --help)
    usage
    exit 0
    ;;
  --simulate)
    simulate=1
    ;;
  --zsh)
    selected_zsh=1
    selection_count=$((selection_count + 1))
    ;;
  --tmux)
    selected_tmux=1
    selection_count=$((selection_count + 1))
    ;;
  --ghostty)
    selected_ghostty=1
    selection_count=$((selection_count + 1))
    ;;
  --herdr)
    selected_herdr=1
    selection_count=$((selection_count + 1))
    ;;
  --nvim)
    selected_nvim=1
    selection_count=$((selection_count + 1))
    ;;
  --claude)
    selected_claude=1
    selection_count=$((selection_count + 1))
    ;;
  -*)
    printf 'install.sh: unknown option: %s\n' "$argument" >&2
    usage >&2
    exit 2
    ;;
  *)
    printf 'install.sh: unexpected positional argument: %s\n' "$argument" >&2
    usage >&2
    exit 2
    ;;
  esac
done

if [ "$selection_count" -eq 0 ]; then
  selected_zsh=1
  selected_tmux=1
  selected_ghostty=1
  selected_herdr=1
  selected_nvim=1
  selected_claude=1
fi

if [ -z "${HOME:-}" ]; then
  fail 'HOME must be set' || exit 1
fi

CONFIG_ROOT=${XDG_CONFIG_HOME:-$HOME/.config}
platform=$(uname -s)

if ! command -v stow >/dev/null 2>&1; then
  fail 'GNU Stow (stow) is required but was not found in PATH' || exit 1
fi

check_package() {
  package=$1
  package_root=$REPO_ROOT/packages/$package
  if [ ! -d "$package_root" ] || [ ! -r "$package_root" ] || [ ! -x "$package_root" ]; then
    fail "selected Stow package is missing or unreadable: $package_root" || return 1
  fi
}

if [ "$selected_zsh" -eq 1 ]; then check_package zsh || exit 1; fi
if [ "$selected_tmux" -eq 1 ]; then check_package tmux || exit 1; fi
if [ "$selected_ghostty" -eq 1 ]; then
  if [ "$platform" = Darwin ]; then
    check_package ghostty-macos || exit 1
  else
    check_package ghostty || exit 1
  fi
fi
if [ "$selected_herdr" -eq 1 ]; then check_package herdr || exit 1; fi
if [ "$selected_nvim" -eq 1 ]; then check_package nvim || exit 1; fi
if [ "$selected_claude" -eq 1 ]; then check_package claude || exit 1; fi

run_stow() {
  target=$1
  shift
  if [ "$simulate" -eq 1 ]; then
    if [ ! -d "$target" ]; then
      simulation_target=$(mktemp -d "${TMPDIR:-/tmp}/myDotFiles-stow.XXXXXX") || {
        fail "cannot create temporary simulation target"
        return 1
      }
      stow --dir="$REPO_ROOT/packages" --target="$simulation_target" --dotfiles --simulate --verbose "$@"
      stow_status=$?
      rmdir "$simulation_target" 2>/dev/null || :
      return "$stow_status"
    fi
    stow --dir="$REPO_ROOT/packages" --target="$target" --dotfiles --simulate --verbose "$@"
  else
    stow --dir="$REPO_ROOT/packages" --target="$target" --dotfiles "$@"
  fi
}

CLAUDE_STATUS_LINE='{"type":"command","command":"~/.claude/statusline.sh","refreshInterval":60}'

# settings.json belongs to Claude Code, so only add the statusLine entry when it is missing.
enable_claude_status_line() {
  settings=$HOME/.claude/settings.json
  if ! command -v jq >/dev/null 2>&1; then
    printf 'install.sh: jq not found; add the statusLine entry from README.md to %s\n' "$settings" >&2
    return 0
  fi
  if [ -e "$settings" ]; then
    jq -e 'has("statusLine")' "$settings" >/dev/null 2>&1
    case $? in
    0) return 0 ;;
    1) ;;
    *)
      printf 'install.sh: %s is not a JSON object; add the statusLine entry from README.md by hand\n' "$settings" >&2
      return 0
      ;;
    esac
  fi
  if [ "$simulate" -eq 1 ]; then
    printf 'Would add statusLine to %s\n' "$settings"
    return 0
  fi
  settings_tmp=$(mktemp "${TMPDIR:-/tmp}/myDotFiles-claude.XXXXXX") || {
    fail 'cannot create temporary settings file'
    return 1
  }
  if [ -e "$settings" ]; then
    jq --argjson status_line "$CLAUDE_STATUS_LINE" '. + {statusLine: $status_line}' "$settings" >"$settings_tmp"
  else
    jq -n --argjson status_line "$CLAUDE_STATUS_LINE" '{statusLine: $status_line}' >"$settings_tmp"
  fi && cat "$settings_tmp" >"$settings"
  settings_status=$?
  rm -f "$settings_tmp"
  if [ "$settings_status" -ne 0 ]; then
    fail "cannot update $settings"
    return 1
  fi
  printf 'Added statusLine to %s\n' "$settings"
}

if [ "$selected_zsh" -eq 1 ]; then
  run_stow "$HOME" zsh || exit $?
fi
if [ "$selected_tmux" -eq 1 ]; then
  # Keep the Stow target directory real so TPM can add external plugin checkouts.
  run_stow "$HOME" --no-folding tmux || exit $?
fi
if [ "$selected_claude" -eq 1 ]; then
  # Keep ~/.claude real: Claude Code stores sessions, history, and settings there.
  run_stow "$HOME" --no-folding claude || exit $?
  enable_claude_status_line || exit $?
fi
config_packages=
if [ "$selected_ghostty" -eq 1 ]; then
  if [ "$platform" = Darwin ]; then
    config_packages="$config_packages ghostty-macos"
  else
    config_packages="$config_packages ghostty"
  fi
fi
if [ "$selected_herdr" -eq 1 ]; then config_packages="$config_packages herdr"; fi
if [ "$selected_nvim" -eq 1 ]; then config_packages="$config_packages nvim"; fi
if [ -n "$config_packages" ]; then
  if [ "$simulate" -eq 0 ] && ! mkdir -p "$CONFIG_ROOT"; then
    fail "cannot create configuration target: $CONFIG_ROOT" || exit 1
  fi
  set -- $config_packages
  run_stow "$CONFIG_ROOT" "$@" || exit $?
fi

if [ "$simulate" -eq 1 ]; then
  printf 'Simulated selected configuration deployment\n'
else
  printf 'Deployed selected configuration through GNU Stow\n'
fi
