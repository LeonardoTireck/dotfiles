#!/bin/sh

set -u

usage() {
  cat <<EOF
Usage: $(basename "$0") [--zsh] [--tmux] [--ghostty] [--herdr] [--nvim]

Without flags, all supported groups are installed: zsh, tmux, ghostty, herdr, and nvim.
Selection flags may be combined or repeated to install their union.

Options:
  --zsh       Install the Zsh configuration.
  --tmux      Install the tmux configuration and bundled Catppuccin plugin.
  --ghostty   Install Ghostty configuration and themes.
  --herdr     Install Herdr configuration.
  --nvim      Install the Neovim configuration.
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

for argument; do
  case $argument in
  --help)
    usage
    exit 0
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
STATE_ROOT=${XDG_STATE_HOME:-$HOME/.local/state}

check_source() {
  source_path=$1
  source_kind=$2

  case $source_kind in
  file)
    if [ ! -f "$source_path" ] || [ ! -r "$source_path" ]; then
      fail "selected source is missing or unreadable: $source_path" || return 1
    fi
    ;;
  directory)
    if [ ! -d "$source_path" ] || [ ! -r "$source_path" ] || [ ! -x "$source_path" ]; then
      fail "selected source is missing or unreadable: $source_path" || return 1
    fi
    ;;
  esac
}

preflight_group() {
  group=$1

  case $group in
  zsh)
    check_source "$REPO_ROOT/terminal/.zshrc" file || return 1
    ;;
  tmux)
    check_source "$REPO_ROOT/.tmux/.tmux.conf" file || return 1
    check_source "$REPO_ROOT/.tmux/plugins/catppuccin-tmux" directory || return 1
    ;;
  ghostty)
    check_source "$REPO_ROOT/ghostty/config" file || return 1
    check_source "$REPO_ROOT/ghostty/themes" directory || return 1
    ;;
  herdr)
    check_source "$REPO_ROOT/herdr/config.toml" file || return 1
    ;;
  nvim)
    check_source "$REPO_ROOT/nvim" directory || return 1
    ;;
  esac
}

if [ "$selected_zsh" -eq 1 ]; then preflight_group zsh || exit 1; fi
if [ "$selected_tmux" -eq 1 ]; then preflight_group tmux || exit 1; fi
if [ "$selected_ghostty" -eq 1 ]; then preflight_group ghostty || exit 1; fi
if [ "$selected_herdr" -eq 1 ]; then preflight_group herdr || exit 1; fi
if [ "$selected_nvim" -eq 1 ]; then preflight_group nvim || exit 1; fi

BACKUP_ROOT=
create_backup_root() {
  backup_parent=$STATE_ROOT/myDotFiles/backups
  if [ -z "$BACKUP_ROOT" ]; then
    if ! mkdir -p "$backup_parent"; then
      fail "cannot create backup directory: $backup_parent" || return 1
    fi

    timestamp=$(date +%Y%m%d%H%M%S) || {
      fail 'cannot create a backup run id' || return 1
    }
    suffix=0
    while :; do
      if [ "$suffix" -eq 0 ]; then
        run_id=$timestamp-$$
      else
        run_id=$timestamp-$$-$suffix
      fi
      candidate=$backup_parent/$run_id
      if mkdir "$candidate" 2>/dev/null; then
        BACKUP_ROOT=$candidate
        break
      fi
      if [ ! -e "$candidate" ]; then
        fail "cannot create backup run directory: $candidate" || return 1
      fi
      suffix=$((suffix + 1))
    done
  fi
}

create_backup_root || exit 1

BACKUP_PATH=
prepare_destination() {
  destination=$1
  destination_parent=$(dirname "$destination")
  if ! mkdir -p "$destination_parent"; then
    fail "cannot create destination directory: $destination_parent" || return 1
  fi
}

backup_destination() {
  destination=$1
  group=$2
  BACKUP_PATH=

  if [ -e "$destination" ] || [ -L "$destination" ]; then
    group_backup=$BACKUP_ROOT/$group
    if ! mkdir -p "$group_backup"; then
      fail "cannot create group backup directory: $group_backup" || return 1
    fi
    BACKUP_PATH=$group_backup/$(basename "$destination")
    if ! mv "$destination" "$BACKUP_PATH"; then
      fail "cannot back up existing destination: $destination" || return 1
    fi
    printf 'Backed up %s to %s\n' "$destination" "$BACKUP_PATH"
  fi
}

restore_destination() {
  destination=$1
  if [ -e "$destination" ] || [ -L "$destination" ]; then
    rm -rf "$destination" || return 1
  fi
  if [ -n "$BACKUP_PATH" ] && { [ -e "$BACKUP_PATH" ] || [ -L "$BACKUP_PATH" ]; }; then
    mv "$BACKUP_PATH" "$destination"
  fi
}

copy_target() {
  source_path=$1
  destination=$2
  group=$3
  source_kind=$4

  prepare_destination "$destination" || return 1
  backup_destination "$destination" "$group" || return 1

  if [ "$source_kind" = directory ]; then
    cp -R "$source_path" "$destination"
  else
    cp "$source_path" "$destination"
  fi
  copy_status=$?
  if [ "$copy_status" -ne 0 ]; then
    if ! restore_destination "$destination"; then
      fail "copy failed and restoration failed: $destination" || return 1
    fi
    fail "copy failed: $source_path -> $destination" || return "$copy_status"
  fi
}

install_group() {
  group=$1

  case $group in
  zsh)
    copy_target "$REPO_ROOT/terminal/.zshrc" "$HOME/.zshrc" zsh file || return 1
    ;;
  tmux)
    copy_target "$REPO_ROOT/.tmux/.tmux.conf" "$HOME/.tmux.conf" tmux file || return 1
    copy_target "$REPO_ROOT/.tmux/plugins/catppuccin-tmux" \
      "$HOME/.tmux/plugins/catppuccin-tmux" tmux directory || return 1
    ;;
  ghostty)
    copy_target "$REPO_ROOT/ghostty/config" "$CONFIG_ROOT/ghostty/config" ghostty file || return 1
    copy_target "$REPO_ROOT/ghostty/themes" "$CONFIG_ROOT/ghostty/themes" ghostty directory || return 1
    ;;
  herdr)
    copy_target "$REPO_ROOT/herdr/config.toml" "$CONFIG_ROOT/herdr/config.toml" herdr file || return 1
    ;;
  nvim)
    copy_target "$REPO_ROOT/nvim" "$CONFIG_ROOT/nvim" nvim directory || return 1
    ;;
  esac

  printf 'Installed %s configuration\n' "$group"
}

if [ "$selected_zsh" -eq 1 ]; then install_group zsh || exit 1; fi
if [ "$selected_tmux" -eq 1 ]; then install_group tmux || exit 1; fi
if [ "$selected_ghostty" -eq 1 ]; then install_group ghostty || exit 1; fi
if [ "$selected_herdr" -eq 1 ]; then install_group herdr || exit 1; fi
if [ "$selected_nvim" -eq 1 ]; then install_group nvim || exit 1; fi
