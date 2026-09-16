# Linux optional dependencies are user-local. This adapter intentionally does
# not inspect Homebrew prefixes.

if [[ -r "$HOME/.local/share/powerlevel10k/powerlevel10k.zsh-theme" ]]; then
  source "$HOME/.local/share/powerlevel10k/powerlevel10k.zsh-theme"
fi

if [[ -r "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
