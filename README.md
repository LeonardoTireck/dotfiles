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

- Zsh: zsh-autosuggestions, zsh-completions, Powerlevel10k, and NVM (`$HOME/.nvm/nvm.sh`).
- Neovim: needs Git + network on first launch to fetch `lazy.nvim`.

Run as your own user, never with `sudo`. Back up any dotfiles that might conflict first — Stow refuses to overwrite them, and the wrapper never auto-adopts or creates backups.

## Preview and install

```sh
sh -n install.sh
stow --version
./install.sh --simulate --zsh --tmux --ghostty --herdr --nvim
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

After editing a package, just rerun its selector.

| Package | Links to |
| --- | --- |
| `packages/zsh` | `$HOME/.zshrc`, `$HOME/.p10k.zsh`, `$HOME/.zshrc.d/` |
| `packages/tmux` | `$HOME/.tmux.conf`, `$HOME/.tmux/` |
| `packages/ghostty` | `${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/` |
| `packages/herdr` | `${XDG_CONFIG_HOME:-$HOME/.config}/herdr/` |
| `packages/nvim` | `${XDG_CONFIG_HOME:-$HOME/.config}/nvim/` |

Use another config root with `XDG_CONFIG_HOME`:

```sh
XDG_CONFIG_HOME="$HOME/.config-work" ./install.sh --simulate --ghostty --nvim
```

## Conflicts and removal

If Stow reports a conflict, your files are left unchanged. Back up or move them explicitly, then rerun. There is no automatic backup.

To unlink while keeping the repo intact, preview then delete:

```sh
stow --dir="$PWD/packages" --target="$HOME" --dotfiles --simulate --verbose --delete zsh tmux
stow --dir="$PWD/packages" --target="$HOME" --dotfiles --delete zsh tmux
stow --dir="$PWD/packages" --target="${XDG_CONFIG_HOME:-$HOME/.config}" --dotfiles --delete ghostty herdr nvim
```
