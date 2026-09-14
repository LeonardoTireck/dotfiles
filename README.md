# myDotFiles

Configuration for Zsh, tmux, Ghostty, Herdr, and Neovim, installed with the
repository's `install.sh` script.

## Quick start

From the repository directory, run:

```sh
./install.sh
```

The script also works from another directory when invoked by its path:

```sh
/path/to/myDotFiles/install.sh
```

With no selection flags, this installs every supported group: `zsh`, `tmux`,
`ghostty`, `herdr`, and `nvim`.

The installer copies files and directories; it does not create symlinks. It
requires `HOME` to be set and a POSIX shell with standard local filesystem
utilities such as `mkdir`, `mv`, `cp`, `dirname`, `basename`, `date`, and `rm`.

## Selecting configurations

Pass one or more flags to install only the requested groups. Flags are additive,
and repeating a flag has no additional effect.

```sh
./install.sh --zsh
./install.sh --tmux --ghostty
./install.sh --herdr --nvim
```

| Flag | Source copied | Destination |
| --- | --- | --- |
| `--zsh` | `term/.zshrc` | `$HOME/.zshrc` |
| `--tmux` | `.tmux/.tmux.conf` and the bundled `catppuccin-tmux` directory | `$HOME/.tmux.conf` and `$HOME/.tmux/plugins/catppuccin-tmux/` |
| `--ghostty` | `ghostty/config` and `ghostty/themes/` | `${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config` and `${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/themes/` |
| `--herdr` | `herdr/config.toml` | `${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml` |
| `--nvim` | The complete `nvim/` tree | `${XDG_CONFIG_HOME:-$HOME/.config}/nvim/` |

Use `--help` to print the command syntax and available flags without changing
any destination:

```sh
./install.sh --help
```

Unknown options and positional arguments are errors. They exit with status 2
before any destination is changed.

## Configuration and backup locations

The installer uses these environment variables:

| Variable | Used for | Default when unset or empty |
| --- | --- | --- |
| `HOME` | Zsh, tmux, and fallback locations | Required; there is no default |
| `XDG_CONFIG_HOME` | Ghostty, Herdr, and Neovim | `$HOME/.config` |
| `XDG_STATE_HOME` | Installer backups | `$HOME/.local/state` |

For example, to install into isolated XDG directories:

```sh
XDG_CONFIG_HOME="$HOME/.config-work" \
XDG_STATE_HOME="$HOME/.local/state-work" \
  ./install.sh --ghostty --nvim
```

## Existing files and recovery

Before replacing an existing file, directory, or symlink, the installer moves it
to a unique run directory:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/myDotFiles/backups/<run-id>/<group>/
```

The original object keeps its basename inside the group directory. For example,
an existing `.zshrc` is backed up as:

```text
.../backups/<run-id>/zsh/.zshrc
```

Backups are retained and are not deleted automatically. To restore one, first
move the installed destination out of the way, then move the matching backup
back to the original destination. For example:

```sh
backup_root="${XDG_STATE_HOME:-$HOME/.local/state}/myDotFiles/backups/<run-id>"
mv "$HOME/.zshrc" "$HOME/.zshrc.installed"
mv "$backup_root/zsh/.zshrc" "$HOME/.zshrc"
```

The script validates every source for every selected group before changing any
managed destination. If a replacement copy fails after a backup was made, it
removes the partial replacement, attempts to restore that destination, and exits
non-zero. If a later group fails, earlier groups that completed successfully are
left installed and their backups remain available.

## What the installer does not do

The installer performs local filesystem operations only. It does not install
operating-system packages, applications, language runtimes, or external
dependencies, and it does not run a package manager or network client.

Install the applications separately before using their configurations:

- Zsh
- tmux
- Ghostty
- Herdr
- Neovim

Some configurations also expect optional tools or plugins that must be installed
separately:

- The tmux configuration expects TPM and tmux-resurrect. The repository-managed
  Catppuccin tmux directory is copied by `--tmux`, but TPM itself is not.
- The Neovim configuration uses LazyVim and `lazy.nvim`. On first Neovim launch,
  the configuration can bootstrap `lazy.nvim` and fetch its plugins through Git;
  this happens in Neovim, not in `install.sh`.
- The Zsh configuration can use zsh-completions, zsh-autosuggestions, and
  Powerlevel10k when their expected files already exist. Missing optional files
  are skipped.

The `github/` group is not an installable group. In particular,
`github/github-recovery-codes.txt` is never copied because it contains sensitive
credentials.

## Testing the installer

The dependency-free integration tests use temporary home and XDG directories,
so they do not modify the current user's configuration:

```sh
sh -n install.sh
sh tests/install_test.sh
```
