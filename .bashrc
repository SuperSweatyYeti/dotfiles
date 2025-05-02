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

# Set default editor
# If neovim exists then set alias
# if ! [[ $(command -v nvim &>/dev/null) ]]; then
# 	alias vim='nvim'
# 	EDITOR='nvim'
# 	SUDO_EDITOR='nvim'
# elif ! [[ $(command -v vim &>/dev/null) ]]; then
# 	EDITOR='vim'
# 	SUDO_EDITOR='vim'
# else
# 	: # Do nothing
# fi

# My wonderful hgrep function which uses awk to grep with headers!
if test -e ~/.config/bashrc-plus/hgrep.bash; then
	source  ~/.config/bashrc-plus/hgrep.bash
fi

# Helper function related to hgrep
# Some commands don't output their headers if they are being piped
# Example: flatpak list
outty() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: outty COMMAND [ARGS]"
    echo "Runs COMMAND in a pseudo-terminal to preserve headers"
    return 1
  fi
  
  # Use either script, unbuffer, or stdbuf
  if command -v script &>/dev/null; then
    script -qc "$*" /dev/null
  elif command -v unbuffer &>/dev/null; then
    unbuffer $@
  elif command -v stdbuf &>/dev/null; then
    stdbuf -i0 -o0 -e0 $@
  else
    echo "Error: No TTY emulation tool found. Install 'util-linux' for script or 'expect' for unbuffer."
    return 1
  fi
}

# Cheat function to curl for examples of a command using https://cheat.sh
if command -v curl &>/dev/null; then
	function cheatsh(){
		# First argument will be the command we
		# want to see examples for
		curl -s https://cheat.sh/${1}
	}
fi

# Set default editor
if command -v nvim &>/dev/null; then
	alias vim='nvim'
	EDITOR='nvim'
	SUDO_EDITOR='nvim'
elif command -v vim &>/dev/null; then
	EDITOR='vim'
	SUDO_EDITOR='vim'
fi

# # Distro Specific settings
# IF we are Ubuntu
if lsb_release -a 2>/dev/null | grep -qiE "Distributor\sID:\sUbuntu"; then
	alias sudoedit='sudo -E -s $EDITOR'
	# IF fzf is installed then
	if command -v fzf &>/dev/null; then
		if test -e /usr/share/fzf/shell/key-bindings.bash; then
			source /usr/share/fzf/shell/key-bindings.bash
		elif test -e /usr/share/doc/fzf/examples/key-bindings.bash; then
			source /usr/share/doc/fzf/examples/key-bindings.bash
		fi
	fi

# IF we are Debian
elif lsb_release -a 2>/dev/null | grep -qiE "Distributor\sID:\sDebian"; then
	alias sudoedit='sudo -E -s $EDITOR'
	# IF fzf is installed then
	if command -v fzf &>/dev/null; then
		if test -e /usr/share/fzf/shell/key-bindings.bash; then
			source /usr/share/fzf/shell/key-bindings.bash
		fi
	fi

# IF we are Fedora
elif lsb_release -a 2>/dev/null | grep -qiE "Distributor\sID:\sFedora"; then
	# IF fzf is installed then
	if command -v fzf &>/dev/null; then
		if test -e /usr/share/fzf/shell/key-bindings.bash; then
			source /usr/share/fzf/shell/key-bindings.bash
		fi
	fi
# IF we are NixOs
elif lsb_release -a 2>/dev/null | grep -qiE "Distributor\sID:\sNixOS"; then
	if command -v fzf-share >/dev/null; then
		source "$(fzf-share)/key-bindings.bash"
		source "$(fzf-share)/completion.bash"
	fi
else
	: # do nothing
fi

# fzf find hidden alias using find
if command -v fzf &>/dev/null; then
  fzf-hidden() {
    find . -type f \( -path "*/.git/*" -prune -o -print \) 2>/dev/null | fzf
  }
fi

# If lsd is installed then use that for nicer listings
if command -v lsd &>/dev/null; then
	alias ls="lsd"
	alias ll="lsd -al"
else
	alias ll="ls -al"
fi

if command -v kf5-config &>/dev/null; then
	alias kdelogout="qdbus org.kde.LogoutPrompt /LogoutPrompt  org.kde.LogoutPrompt.promptLogout"
fi

# fzf function IF fzf is installed
if command -v fzf &>/dev/null; then
	# fzf config
	# # ripgrep->fzf->nvim [QUERY]
	# fuzzy ripgrep search to enter with nvim ctrl + o
	rfz() {
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
	}

	fz() {
		fzf --ansi \
			--bind "ctrl-o:become:$EDITOR" \
			--delimiter : \
			--preview 'bat --style=full --color=always {}' \
			--bind 'alt-j:preview-down' \
			--bind 'alt-k:preview-up' \
			--preview-window '~4,+{2}+4/3,<80(up)'
	}

	alias cdfz='cd $(find . -type d -print | fzf ) '

	# Set up fzf key bindings and fuzzy completion
	# depending on installation "fzf --bash" won't be neccessary
	if command -v "fzf --bash" &>/dev/null; then
		eval "$(fzf --bash)"
	fi

fi


# Old Custom prompts
# PS1 Prompt
#PS1="\n╭╴$(tput setaf 46)\u$(tput sgr0)@$(tput setaf 105)\h$(tput sgr0) \w \n╰─ \$ "
#PS1="\n╭╴$(tput bold; tput setaf 75)\u$(tput sgr0)@$(tput bold; tput setaf 176)\h$(tput sgr0) \[$(tput bold; tput setaf 116)\]\w\[$(tput sgr0)\] \n╰─ \$ "

# # Tokyo Night
# # Define colors using termcap (tput alternative)
# COLOR1=$(tput bold; tput setaf 75)   # Cyan (User)
# COLOR2=$(tput bold; tput setaf 13)   # Magenta (Host)
# COLOR3=$(tput bold; tput setaf 75)   # Teal (Directory)
# COLOR4=$(tput bold; tput setaf 178)  # Yellow (At @ symbol)
# RESET=$(tput sgr0)
#
# # Set the PS1 prompt
# PS1="\n╭╴${COLOR1}\u${RESET}${COLOR4}@${RESET}${COLOR2}\h${RESET} ${COLOR3}\w${RESET} \n╰─ \$ "

# Function to get Git branch and status
# git_prompt() {
# 	local branch
# 	branch="$(git symbolic-ref HEAD 2>/dev/null | cut -d'/' -f3-)"
# 	local branch_truncated="${branch:0:30}"
# 	if ((${#branch} > ${#branch_truncated})); then
# 		branch="${branch_truncated}..."
# 	fi
#
# 	[ -n "${branch}" ] && echo " (  ${branch} )"
# }

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
PS1="\n╭╴${COLOR1}\u${RESET}${COLOR4}@${RESET}${COLOR2}\h${RESET} ${COLOR3}\w${RESET} \n╰─ \$ "

# Add some nice git status to the prompt ONLY if git is installed
if command -v git &>/dev/null; then

	# Function to get Git branch and status
	# Function to get Git branch and change color based on status
	git_prompt() {
		local branch color modified_files staged_files unstaged_files stash_count behind_count ahead_count prompt

		# Get the current branch
		branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return

		# Count of staged files (modified or added but not committed yet)
		staged_files=$(git status --short 2>/dev/null | grep -c "^[AM]")

		# Count of unstaged files (modified but not added to the staging area)
		unstaged_files=$(git status --short 2>/dev/null | grep -c "^ M")

		# Count of modified files (staged or unstaged)
		modified_files=$((staged_files + unstaged_files))

		# Check for stashes
		stash_count=$(git stash list 2>/dev/null | wc -l)

		# Check if the local branch is behind or ahead of the remote
		behind_count=$(git rev-list --left-only --count HEAD...origin/"$branch" 2>/dev/null)
		ahead_count=$(git rev-list --right-only --count HEAD...origin/"$branch" 2>/dev/null)

		# Set colors based on repo status
		if git diff --quiet --ignore-submodules HEAD 2>/dev/null; then
			color=$(tput setaf 114) # Soft Green (Clean repo)
		else
			color=$(tput setaf 185) # Soft Yellow (Uncommitted changes)
		fi

		# Initialize the prompt string
		prompt="${color} ${branch}${RESET}"

		# Add the number of modified files with the page icon (󰷉)
		if [ "$modified_files" -gt 0 ]; then
			prompt="${prompt} ${modified_files}󰷉"
		fi

		# Add the number of staged files with the check mark icon (✔️)
		if [ "$staged_files" -gt 0 ]; then
			prompt="${prompt} ${staged_files}✔️"
		fi

		# Add the number of unstaged files with the reload/refresh icon (󰜞)
		if [ "$unstaged_files" -gt 0 ]; then
			prompt="${prompt} ${unstaged_files}󰜞"
		fi

		# Add the number of stashes with the package icon (📦)
		if [ "$stash_count" -gt 0 ]; then
			prompt="${prompt} ${stash_count}📦"
		fi

		# Add behind and ahead status with icons
		if [ "$behind_count" -gt 0 ]; then
			prompt="${prompt} ${behind_count}(Ahead)"
		fi
		if [ "$ahead_count" -gt 0 ]; then
			prompt="${prompt} ${ahead_count}(Behind)"
		fi

		# Return the prompt string
		echo -n "$prompt" ⇒
	}

	git_repo_name() {
		# Get the repository name by parsing the git remote URL
		git remote get-url origin 2>/dev/null | sed -E 's/.*[:\/]([^\/]+)\/([^\/]+).*/\2/'
	}
	# Set Bash prompt
	PS1="\n╭╴${COLOR1}\u${RESET}${COLOR4}@${RESET}${COLOR2}\h${RESET} ${COLOR3}\w${RESET} ${COLOR5}\$(git_prompt) \$(git_repo_name)${RESET} \n╰─ \$ "
fi

# IF lazygit is installed without using brew
if command -v lazygit &>/dev/null; then
	alias lg='lazygit'
fi

# Yazi config
# ONLY if yazi is installed without using brew
if command -v yazi &>/dev/null; then
	# cd into directory when leaving yazi
	# cdyaz() {
	# 	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	# 	yazi "$@" --cwd-file="$tmp"
	# 	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
	# 		builtin cd -- "$cwd"
	# 	fi
	# 	rm -f -- "$tmp"
	# }
	# cd into directory when leaving yazi
	function cdyazi() {
	    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
	    
	    # Filter out --cwd-file from the arguments passed to yazi, if present
	    local args=()
	    for arg in "$@"; do
		if [[ "$arg" != --cwd-file* ]]; then
		    args+=("$arg")
		fi
	    done
	    
	    # Now call yazi with the modified args and add --cwd-file="$tmp" once
	    yazi "${args[@]}" --cwd-file="$tmp"
	    
	    # Handle cwd change
	    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	    fi
	    
	    # Clean up the temporary file
	    rm -f -- "$tmp"
	}
	
	alias y='yazi'
	alias cdy='cdyazi'
fi


# linux homebrew
# Only IF brew is installed
if command -v "/home/linuxbrew/.linuxbrew/bin/brew" &>/dev/null; then
	eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

	# Aliases for brew installed applications
	# IF lazygit is installed with brew then make an alias for it
	if command -v lazygit &>/dev/null; then
		alias lg='lazygit'
	fi
	# Yazi config
	# ONLY if yazi is installed using brew
	if command -v yazi &>/dev/null; then
		# cd into directory when leaving yazi
		function cdyazi() {
			local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
			yazi "$@" --cwd-file="$tmp"
			if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
				builtin cd -- "$cwd"
			fi
			rm -f -- "$tmp"
		}
		alias y='yazi'
		alias cdy='cdyazi'
	fi
fi

# Carapace bash completion additions
if command -v "carapace" &>/dev/null; then
	export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense,nu' # optional
	source <(carapace _carapace)
	# No errors if when tabbing on unknown flags
	export CARAPACE_LENIENT=1
fi

