# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc


######## Custom
#alias lf="lfrun"
alias ranger=". ranger"
alias ll="ls -al"
alias kdelogout="qdbus org.kde.LogoutPrompt /LogoutPrompt  org.kde.LogoutPrompt.promptLogout"


# fzf config
# # ripgrep->fzf->nvim [QUERY]
# fuzzy ripgrep search to enter with nvim ctrl + o
rfz() (
  RELOAD='reload:rg --column --color=always --smart-case {q} || :'
  OPENER='if [[ $FZF_SELECT_COUNT -eq 0 ]]; then
            nvim {1} +{2}     # No selection. Open the current line in nvim.
          fi'
  fzf --disabled --ansi  \
      --bind "start:$RELOAD" --bind "change:$RELOAD" \
      --bind "ctrl-o:become:$OPENER" \
      --bind 'ctrl-/:toggle-preview' \
      --delimiter : \
      --preview 'bat --style=full --color=always --highlight-line {2} {1}' \
      --preview-window '~4,+{2}+4/3,<80(up)' \
      --query "$*"
)
# fuzzy search to enter with nvim ctrl + o

fz() (
  fzf --ansi \
      --bind "ctrl-o:become:$EDITOR" \
      --delimiter : \
      --preview 'bat --style=full --color=always {}' \
      --bind 'alt-j:preview-down' \
      --bind 'alt-k:preview-up' \
      --preview-window '~4,+{2}+4/3,<80(up)'
)

alias cdfz='cd $(find . -type d -print | fzf ) '

# Set up fzf key bindings and fuzzy completion
eval "$(fzf --bash)"




# Yazi config
# cd into directory when leaving yazi
cdy() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}


#alias btop="bpytop"
#alias ld="lsd"
#alias lld="lsd -al"

EDITOR='nvim'

PS1="\n┌─ $(tput setaf 46)\u$(tput sgr0)@$(tput setaf 105)\h$(tput sgr0) \w \n└─╼ \$ "
#PS1="\n┌─ $(tput setaf 115)\u$(tput sgr0)@$(tput setaf 105)\h$(tput sgr0) \w \n└─╼ \$ "

force_color_prompt=yes

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
