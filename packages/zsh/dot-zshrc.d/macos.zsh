# macOS optional dependencies. Do not install or update anything here.

typeset -a mydotfiles_brew_prefixes
mydotfiles_brew_prefixes=()
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  mydotfiles_brew_prefixes+=("$HOMEBREW_PREFIX")
fi
mydotfiles_brew_prefixes+=(/opt/homebrew /usr/local)

for mydotfiles_prefix in $mydotfiles_brew_prefixes; do
  if [[ -r "$mydotfiles_prefix/share/powerlevel10k/powerlevel10k.zsh-theme" ]]; then
    source "$mydotfiles_prefix/share/powerlevel10k/powerlevel10k.zsh-theme"
    break
  fi
done

if [[ -r "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
else
  for mydotfiles_prefix in $mydotfiles_brew_prefixes; do
    if [[ -r "$mydotfiles_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
      source "$mydotfiles_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
      break
    fi
  done
fi

for mydotfiles_prefix in $mydotfiles_brew_prefixes; do
  if [[ -d "$mydotfiles_prefix/share/zsh-completions/src" ]]; then
    fpath=("$mydotfiles_prefix/share/zsh-completions/src" $fpath)
    break
  fi
done

autoload -Uz compinit
compinit -i
typeset -g MYDOTFILES_COMPLETION_INITIALIZED=1
