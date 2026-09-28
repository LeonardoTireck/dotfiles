# dot files

Configs for Zsh, tmux, Ghostty, Herdr, and Neovim. `install.sh` links them into place with GNU Stow.

## Prerequisites

```sh
git clone https://github.com/LeonardoTireck/dotfiles.git
cd dotfiles
```

Install GNU Stow plus the apps you use: Zsh, tmux, Ghostty, Herdr, Neovim.

- macOS: `brew bundle --file=Brewfile` (install [Homebrew](https://brew.sh/) first if needed).
- Linux: use your distro packages or the apps' official instructions.

`install.sh` only creates symlinks. It does not install packages or contact the network.

Optional, only if you use them:

- Zsh: zsh-autosuggestions, zsh-completions, Powerlevel10k, and NVM (`$HOME/.nvm/nvm.sh`). On Linux, Powerlevel10k may live in `~/powerlevel10k` or `~/.local/share/powerlevel10k`.
- Ghostty: the macOS profile uses JetBrainsMono Nerd Font; the Linux profile uses FiraCode Nerd Font Med. Install the matching font if you want that exact appearance.
- Neovim: needs Git + network on first launch to fetch `lazy.nvim`.

Run as your own user, never with `sudo`. Back up any dotfiles that might conflict first — Stow refuses to overwrite them, and the wrapper never auto-adopts or creates backups.

## Preview and install

If an older macOS installation links `~/.config/ghostty` to `packages/ghostty/ghostty`, remove that managed link before installing the Mac profile:

```sh
stow --dir="$PWD/packages" --target="${XDG_CONFIG_HOME:-$HOME/.config}" --dotfiles --simulate --verbose --delete ghostty
stow --dir="$PWD/packages" --target="${XDG_CONFIG_HOME:-$HOME/.config}" --dotfiles --delete ghostty
```

```sh
sh -n install.sh
stow --version
./install.sh --simulate --zsh --tmux --ghostty --herdr --nvim
sh tests/cross_platform_config_test.sh
./install.sh
```

No selectors means all five packages. If the simulation looks right, run `./install.sh` for real.

Verify, then restart the apps to load the new configs:

```sh
ls -l "$HOME/.zshrc" "$HOME/.p10k.zsh" "$HOME/.tmux.conf" "$HOME/.tmux"
ls -l "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty" "${XDG_CONFIG_HOME:-$HOME/.config}/herdr" "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
```

See `./install.sh --help` for all options.

## Set up tmux plugins

TPM and upstream plugins are external to this repository. 'install.sh' does not install TPM, run Git, or fetch plugins. Do these steps in order, before starting or reloading tmux.

1. Install TPM. TPM is a separate prerequisite at `$HOME/.tmux/plugins/tpm`. Skip this command if that checkout already exists:

   ```sh
   git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
   ```

2. Inspect '$HOME/.tmux.conf' and '$HOME/.tmux/' for user-owned files that would conflict. Back up or explicitly migrate those files before continuing, then deploy tmux:

   ```sh
   ./install.sh --tmux
   ```

   `$HOME/.tmux/` holds both the repository-owned Catppuccin files and TPM-managed plugins.

3. Reload tmux:

   ```sh
   tmux source-file "$HOME/.tmux.conf"
   ```

4. In tmux, press prefix + I. TPM fetches the declared plugins, including 'tmux-plugins/tmux-resurrect', into '$HOME/.tmux/plugins/' and reloads the tmux environment. Catppuccin is already loaded from the Stow-managed local entrypoint, so it is not listed as a TPM plugin.

## Install only what you need

Selectors are additive and repeatable:

```sh
./install.sh --zsh
./install.sh --tmux --ghostty
./install.sh --herdr --nvim
```

Edits to linked files take effect when the app reloads. Rerun a selector after adding files to a package.

Zsh loads `~/.zshrc.d/macos.zsh` on macOS and `~/.zshrc.d/linux.zsh` on Linux. The Linux adapter keeps the previous PATH order and supports the existing `~/powerlevel10k` prompt. Linux autosuggestions can be enabled with `MYDOTFILES_LINUX_AUTOSUGGESTIONS=1`.

Ghostty uses `${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/` on both systems. Linux deploys the unchanged `packages/ghostty` profile, so an existing Linux Stow link continues working after a pull. macOS deploys `packages/ghostty-macos` to the same location, with the Mac shortcuts, font, window settings, and a link to the shared custom themes.

| Package | Links to |
| --- | --- |
| `packages/zsh` | `$HOME/.zshrc`, `$HOME/.p10k.zsh`, `$HOME/.zshrc.d/` |
| `packages/tmux` | `$HOME/.tmux.conf`, `$HOME/.tmux/` |
| `packages/ghostty` (Linux) | `${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/` |
| `packages/ghostty-macos` (macOS) | `${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/` |
| `packages/herdr` | `${XDG_CONFIG_HOME:-$HOME/.config}/herdr/` |
| `packages/nvim` | `${XDG_CONFIG_HOME:-$HOME/.config}/nvim/` |

Use another config root with `XDG_CONFIG_HOME`:

```sh
XDG_CONFIG_HOME="$HOME/.config-work" ./install.sh --simulate --ghostty --nvim
```

## Conflicts and removal

Stow does not overwrite a conflicting file. When multiple groups are selected, earlier groups may already have been linked before a later group reports a conflict. Back up or move the conflicting file explicitly, then rerun. There is no automatic backup.

To unlink while keeping the repo intact, preview then delete:

```sh
stow --dir="$PWD/packages" --target="$HOME" --dotfiles --simulate --verbose --delete zsh tmux
stow --dir="$PWD/packages" --target="$HOME" --dotfiles --delete zsh tmux
# Linux:
stow --dir="$PWD/packages" --target="${XDG_CONFIG_HOME:-$HOME/.config}" --dotfiles --simulate --verbose --delete ghostty herdr nvim
stow --dir="$PWD/packages" --target="${XDG_CONFIG_HOME:-$HOME/.config}" --dotfiles --delete ghostty herdr nvim
# macOS:
stow --dir="$PWD/packages" --target="${XDG_CONFIG_HOME:-$HOME/.config}" --dotfiles --simulate --verbose --delete ghostty-macos herdr nvim
stow --dir="$PWD/packages" --target="${XDG_CONFIG_HOME:-$HOME/.config}" --dotfiles --delete ghostty-macos herdr nvim
```
