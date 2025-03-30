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

# Set Default Editor
# If nvim exists then set alias
if ! [[ $(command -v nvim &>/dev/null) ]]; then
	EDITOR='nvim'
elif ! [[ $(command -v vim &>/dev/null) ]]; then
	EDITOR='vim'
else
	: # Do nothing
fi

# If lsd is installed then use that for nicer listings
if ! [[ $(command -v lsd &>/dev/null) ]]; then
	alias ls="lsd"
	alias ll="lsd -al"
else
	alias ll="ls -al"
fi

alias ranger=". ranger"
alias kdelogout="qdbus org.kde.LogoutPrompt /LogoutPrompt  org.kde.LogoutPrompt.promptLogout"
#alias btop="bpytop"

# fzf function IF fzf is installed
if ! [[ $(command -v fzf &>/dev/null) ]]; then
# fzf config
# # ripgrep->fzf->nvim [QUERY]
# fuzzy ripgrep search to enter with nvim ctrl + o
rfz() (
	RELOAD='reload:rg --column --color=always --smart-case {q} || :'
	OPENER='if [[ $FZF_SELECT_COUNT -eq 0 ]]; then
            nvim {1} +{2}     # No selection. Open the current line in nvim.
          fi'
	fzf --disabled --ansi \
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
# depeding on installation fzf --bash won't be neccessary
if  [[ $(command -v "fzf --bash" &>/dev/null) ]]; then
	eval "$(fzf --bash )"
fi

fi

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

# Old Custom prompts
# PS1 Prompt
#PS1="\n┌─ $(tput setaf 46)\u$(tput sgr0)@$(tput setaf 105)\h$(tput sgr0) \w \n└─╼ \$ "
#PS1="\n┌─ $(tput bold; tput setaf 75)\u$(tput sgr0)@$(tput bold; tput setaf 176)\h$(tput sgr0) \[$(tput bold; tput setaf 116)\]\w\[$(tput sgr0)\] \n└─╼ \$ "

# # Tokyo Night
# # Define colors using termcap (tput alternative)
# COLOR1=$(tput bold; tput setaf 75)   # Cyan (User)
# COLOR2=$(tput bold; tput setaf 13)   # Magenta (Host)
# COLOR3=$(tput bold; tput setaf 75)   # Teal (Directory)
# COLOR4=$(tput bold; tput setaf 178)  # Yellow (At @ symbol)
# RESET=$(tput sgr0)
#
# # Set the PS1 prompt
# PS1="\n┌─ ${COLOR1}\u${RESET}${COLOR4}@${RESET}${COLOR2}\h${RESET} ${COLOR3}\w${RESET} \n└─╼ \$ "

# Function to get Git branch and status
git_prompt() {
	local branch
	branch="$(git symbolic-ref HEAD 2>/dev/null | cut -d'/' -f3-)"
	local branch_truncated="${branch:0:30}"
	if ((${#branch} > ${#branch_truncated})); then
		branch="${branch_truncated}..."
	fi

	[ -n "${branch}" ] && echo " (${branch}) ↔️"
}

git_repo_name() {
	REPO_NAME="$(git remote show -n origin 2>/dev/null | grep Fetch | cut -d: -f2-)"
	REPO_BASENAME="$(basename "$REPO_NAME")"
	[ -n "${REPO_BASENAME}" ] && echo "$REPO_BASENAME"
}

# Catppuccin Mocha
# Define colors using termcap (tput alternative)
COLOR1=$(
	tput bold
	tput setaf 75
) # Blue (User)
COLOR2=$(
	tput bold
	tput setaf 176
) # Pink (Host)
COLOR3=$(
	tput bold
	tput setaf 116
) # Teal (Directory)
COLOR4=$(
	tput bold
	tput setaf 215
) # Bright Yellow-Orange (@ symbol)
COLOR5=$(
	tput bold
) # Bright Yellow-Orange (@ symbol)
RESET=$(tput sgr0)

# Set the PS1 prompt
PS1="\n┌─ ${COLOR1}\u${RESET}${COLOR4}@${RESET}${COLOR2}\h${RESET} ${COLOR3}\w${RESET} ${COLOR5}\$(git_prompt) \$(git_repo_name)${RESET} \n└─╼ \$ "

# linux homebrew
# Only IF brew is installed
if ! [[ $(command -v "/home/linuxbrew/.linuxbrew/bin/brew" &>/dev/null) ]]; then
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
