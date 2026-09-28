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

if [[ "${MYDOTFILES_LINUX_AUTOSUGGESTIONS:-0}" == 1 && -r "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
