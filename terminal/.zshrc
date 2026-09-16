fpath=("$HOME/.zsh/zsh-completions/src" $fpath)

if [[ -r "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

alias myip="curl -s https://checkip.amazonaws.com"
alias myhistory="history | awk '{print \$2}' | sort | uniq -c | sort -rn | head -10"
alias reload="source ~/.zshrc"
alias dcup="docker compose up -d"
alias dcdw="docker compose down"
alias dclog="docker compose logs api --since 30s -f"
alias hr="herdr"


# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

if [[ -r "$HOME/.local/share/powerlevel10k/powerlevel10k.zsh-theme" ]]; then
  source "$HOME/.local/share/powerlevel10k/powerlevel10k.zsh-theme"
fi

export ZSH="$HOME/.oh-my-zsh"

export PATH="$HOME/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

ZSH_THEME="powerlevel10k/powerlevel10k"



# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
if [[ -r "$HOME/.p10k.zsh" ]]; then
  source "$HOME/.p10k.zsh"
fi

# opencode
export PATH="$HOME/.opencode/bin:$PATH"
