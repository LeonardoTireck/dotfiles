# myDotFiles

Configuration for Zsh, tmux, Ghostty, Herdr, and Neovim, deployed with GNU
Stow through the repository's 'install.sh' wrapper.

## Prerequisites

Install GNU Stow and the applications separately. 'install.sh' does not install
packages, invoke a package manager, contact a network client, or run a
dependency bootstrapper.

The configuration can use these optional tools when they are already installed:

- Zsh autosuggestions, zsh-completions, Powerlevel10k, and NVM
- TPM and tmux-resurrect for tmux
- LazyVim and 'lazy.nvim' for Neovim

The Zsh adapters discover optional paths at shell startup. On macOS, the
adapter checks 'HOMEBREW_PREFIX', '/opt/homebrew', and '/usr/local'. It does not
run 'brew'. Linux uses user-local paths and does not inspect Homebrew paths.

## Deploy configuration

Run from the repository directory:

~~~sh
./install.sh
~~~

With no selectors, the wrapper deploys all five packages. Prefer explicit
selectors when changing one group:

~~~sh
./install.sh --zsh
./install.sh --tmux --ghostty
./install.sh --herdr --nvim
./install.sh --zsh --tmux --ghostty --herdr --nvim
~~~

Selectors are additive and repeating a selector has no additional effect.

Use '--help' to print syntax without changing a destination:

~~~sh
./install.sh --help
~~~

Preview the exact selected deployment without changing the filesystem:

~~~sh
./install.sh --simulate --zsh --ghostty
~~~

The simulation passes '--simulate --verbose' to GNU Stow and does not create
the XDG configuration directory.

## Package and destination mapping

Each directory under 'packages/' is a separate GNU Stow package. The wrapper
targets '$HOME' for shell and tmux packages and
'${XDG_CONFIG_HOME:-$HOME/.config}' for application configuration packages.

| Package | Stow installation image | Destination |
| --- | --- | --- |
| 'packages/zsh' | 'dot-zshrc', 'dot-p10k.zsh', 'dot-zshrc.d/' | '$HOME/.zshrc', '$HOME/.p10k.zsh', '$HOME/.zshrc.d/' |
| 'packages/tmux' | 'dot-tmux.conf', 'dot-tmux/' | '$HOME/.tmux.conf', '$HOME/.tmux/' |
| 'packages/ghostty' | 'ghostty/' | '${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/' |
| 'packages/herdr' | 'herdr/' | '${XDG_CONFIG_HOME:-$HOME/.config}/herdr/' |
| 'packages/nvim' | 'nvim/' | '${XDG_CONFIG_HOME:-$HOME/.config}/nvim/' |

'--dotfiles' converts package names beginning with 'dot-' into hidden target
names. GNU Stow owns the links; editing a linked file edits the repository
package directly.

## Existing files and recovery

GNU Stow reports a conflict and exits non-zero when a selected destination is
an existing user-owned file or directory. The wrapper never passes '--adopt',
so it never imports local edits implicitly. Inspect the conflict, make any
migration decision explicitly, and rerun the selected command.

Stow's two-phase conflict check leaves a conflicting target unchanged. There is
no automatic backup directory.

To remove links for a package while keeping the repository package intact, run
the matching delete operation:

~~~sh
stow --dir="$PWD/packages" --target="$HOME" --dotfiles --delete zsh tmux
stow --dir="$PWD/packages" \
  --target="${XDG_CONFIG_HOME:-$HOME/.config}" \
  --dotfiles --delete ghostty herdr nvim
~~~

Run the same commands with '--simulate --verbose' first when reviewing a
recovery:

~~~sh
stow --dir="$PWD/packages" --target="$HOME" \
  --dotfiles --simulate --verbose --delete zsh tmux
~~~

## Configuration targets

'HOME' is required. Zsh and tmux always target:

~~~text
$HOME/.zshrc
$HOME/.p10k.zsh
$HOME/.tmux.conf
$HOME/.tmux/
~~~

Ghostty, Herdr, and Neovim target:

~~~text
${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/
${XDG_CONFIG_HOME:-$HOME/.config}/herdr/
${XDG_CONFIG_HOME:-$HOME/.config}/nvim/
~~~

Set 'XDG_CONFIG_HOME' to use a different configuration root:

~~~sh
XDG_CONFIG_HOME="$HOME/.config-work" ./install.sh --ghostty --nvim
~~~

The wrapper creates a missing XDG target parent during a real deployment. It
does not create it in simulation mode.

## Validation

Check the wrapper syntax before deploying:

~~~sh
sh -n install.sh
~~~

Preview a deployment after installing GNU Stow:

~~~sh
stow --version
./install.sh --simulate --zsh
~~~

Applications and their optional dependencies remain a separate manual
installation concern.
