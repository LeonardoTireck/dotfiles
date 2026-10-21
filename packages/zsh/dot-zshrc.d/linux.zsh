# Linux-specific optional dependencies. Homebrew paths stay in macos.zsh.

export PATH="$HOME/.cargo/bin:$PATH"

for mydotfiles_p10k in \
  "$HOME/powerlevel10k/powerlevel10k.zsh-theme" \
  "$HOME/.local/share/powerlevel10k/powerlevel10k.zsh-theme"; do
  if [[ -r "$mydotfiles_p10k" ]]; then
    source "$mydotfiles_p10k"
    break
  fi
done

for mydotfiles_autosuggestions in \
  "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  if [[ -r "$mydotfiles_autosuggestions" ]]; then
    source "$mydotfiles_autosuggestions"
    break
  fi
done

autoload -Uz compinit
compinit -i
typeset -g MYDOTFILES_COMPLETION_INITIALIZED=1
