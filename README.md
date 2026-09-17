# myDotFiles

Configuration for Zsh, tmux, Ghostty, Herdr, and Neovim, deployed with GNU
Stow through the repository's 'install.sh' wrapper.

## Before you begin

1. Clone the repository and enter it:

~~~sh
git clone https://github.com/LeonardoTireck/dotfiles.git
cd dotfiles
~~~

2. Install GNU Stow. It is the only prerequisite required by 'install.sh'.
Install the applications whose configuration you want to use as well:

- Zsh
- tmux
- Ghostty
- Herdr
- Neovim

On macOS with Homebrew, the included 'Brewfile' installs these tools and the
other integrations used by this repository:

~~~sh
brew bundle --file=Brewfile
~~~

Install [Homebrew](https://brew.sh/) first if it is not already available. On
Linux, install GNU Stow and the applications with your distribution's package
manager or their official installation instructions. 'install.sh' does not
install packages, invoke a package manager, contact a network client, or run a
dependency bootstrapper.

3. Install optional integrations that you want to use:

- Zsh: zsh-autosuggestions, zsh-completions, and Powerlevel10k. Linux paths are
  '$HOME/.zsh/' and '$HOME/.local/share/powerlevel10k/'. macOS paths are the
  Homebrew prefix paths or '$HOME/.zsh/'.
- NVM: the shared Zsh configuration loads '$HOME/.nvm/nvm.sh'. Homebrew's NVM
  installation uses '$HOMEBREW_PREFIX/opt/nvm/nvm.sh', so add that source to
  your shell setup if you use Homebrew's NVM formula.
- tmux: install TPM at '$HOME/.tmux/plugins/tpm'. TPM can then install
  tmux-resurrect. The Catppuccin plugin files are included in this repository.
- Neovim: the first launch clones 'lazy.nvim' when it is missing, then loads
  LazyVim and the configured plugins. Keep Git and network access available for
  that first launch, or install 'lazy.nvim' before starting Neovim.

The Zsh adapters discover optional paths at shell startup. On macOS, the
adapter checks 'HOMEBREW_PREFIX', '/opt/homebrew', and '/usr/local'. It does not
run 'brew'. Linux uses user-local paths and does not inspect Homebrew paths.

4. Decide whether to use the default configuration root or set
'XDG_CONFIG_HOME':

~~~sh
# Default: $HOME/.config
./install.sh --simulate --ghostty --herdr --nvim

# Optional alternate root
XDG_CONFIG_HOME="$HOME/.config-work" ./install.sh --simulate --ghostty --nvim
~~~

The simulation uses a temporary target when the selected XDG root does not
exist, so it does not create the real configuration directory.

5. Run the installer as the user whose home directory should receive the links.
Do not run it with 'sudo'. Inspect existing destinations before the first real
deployment. GNU Stow refuses to replace user-owned files and directories. Back
up or explicitly migrate any existing files that conflict with the selected
package, then rerun the command. The wrapper never uses Stow's '--adopt' option.

## Deploy configuration

Run the syntax check and a simulation from the repository directory:

~~~sh
sh -n install.sh
stow --version
./install.sh --simulate --zsh --tmux --ghostty --herdr --nvim
~~~

When the simulation shows the expected operations, deploy all five packages:

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

The real deployment creates the missing XDG configuration parent, then creates
symlinks through GNU Stow. It does not create backups or install applications.

Verify the resulting links after deployment:

~~~sh
ls -l "$HOME/.zshrc" "$HOME/.p10k.zsh" "$HOME/.tmux.conf" "$HOME/.tmux"
ls -l "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
ls -l "${XDG_CONFIG_HOME:-$HOME/.config}/herdr"
ls -l "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
~~~

Start a new Zsh, tmux session, Ghostty, Herdr, or Neovim process to load the
linked configuration. Neovim may install its plugins during its first launch.

## Update one configuration group

After editing a package file, rerun the matching selector. Selectors can be
combined and repeated selectors have no additional effect:

~~~sh
./install.sh --zsh
./install.sh --tmux --ghostty
./install.sh --herdr --nvim
~~~

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

The wrapper creates a missing XDG target parent during a real deployment. During
simulation it uses a temporary target and leaves the real destination unchanged.

## Validation

Check the wrapper syntax before deploying:

~~~sh
sh -n install.sh
~~~

Preview a deployment after installing GNU Stow:

~~~sh
stow --version
./install.sh --simulate --zsh --tmux --ghostty --herdr --nvim
~~~

Applications and their optional dependencies remain a separate manual
installation concern.
