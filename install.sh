#!/bin/sh

set -u

usage() {
  cat <<EOF
Usage: $(basename "$0") [--simulate] [--zsh] [--tmux] [--ghostty] [--herdr] [--nvim]

Without selectors, all supported groups are deployed: zsh, tmux, ghostty, herdr, and nvim.
Selectors may be combined or repeated. Deployment creates symlinks through GNU Stow.

Options:
  --simulate  Show planned Stow operations without changing the filesystem.
  --zsh       Deploy the Zsh configuration and prompt configuration.
  --tmux      Deploy tmux configuration and bundled Catppuccin plugin.
  --ghostty   Deploy Ghostty configuration and themes.
  --herdr     Deploy Herdr configuration.
  --nvim      Deploy the Neovim configuration.
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
fi

if [ -z "${HOME:-}" ]; then
  fail 'HOME must be set' || exit 1
fi

CONFIG_ROOT=${XDG_CONFIG_HOME:-$HOME/.config}

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
if [ "$selected_ghostty" -eq 1 ]; then check_package ghostty || exit 1; fi
if [ "$selected_herdr" -eq 1 ]; then check_package herdr || exit 1; fi
if [ "$selected_nvim" -eq 1 ]; then check_package nvim || exit 1; fi

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

home_packages=
if [ "$selected_zsh" -eq 1 ]; then home_packages="$home_packages zsh"; fi
if [ "$selected_tmux" -eq 1 ]; then home_packages="$home_packages tmux"; fi
if [ -n "$home_packages" ]; then
  set -- $home_packages
  run_stow "$HOME" "$@" || exit $?
fi

config_packages=
if [ "$selected_ghostty" -eq 1 ]; then config_packages="$config_packages ghostty"; fi
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
