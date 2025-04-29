# .zshrc
# User specific environment
if [[ ! "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
	PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Load any user specific scripts
if [ -d ~/.zshrc.d ]; then
	for rc in ~/.zshrc.d/*; do
		if [ -f "$rc" ]; then
			. "$rc"
		fi
	done
fi
unset rc

# Enable ZSH completion system
autoload -Uz compinit
compinit


# My amazing function to grep with HEADERS!!
if test -e ~/.config/bashrc-plus/hgrep.zsh ; then
	source ~/.config/bashrc-plus/hgrep.zsh
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
		# Use curl in silent mode (-s) to avoid progress output in pipes
		# and allow for proper piping
		curl -s "https://cheat.sh/${1}"
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

# Distro Specific settings
# IF we are Ubuntu
if lsb_release -a 2>/dev/null | grep -qiE "Distributor\sID:\sUbuntu"; then
	alias sudoedit='sudo -E -s $EDITOR'
	# IF fzf is installed then
	if command -v fzf &>/dev/null; then
		if test -e /usr/share/fzf/shell/key-bindings.zsh; then
			source /usr/share/fzf/shell/key-bindings.zsh
		elif test -e /usr/share/doc/fzf/examples/key-bindings.zsh; then
			source /usr/share/doc/fzf/examples/key-bindings.zsh
		fi
	fi

# IF we are Debian
elif lsb_release -a 2>/dev/null | grep -qiE "Distributor\sID:\sDebian"; then
	alias sudoedit='sudo -E -s $EDITOR'
	# IF fzf is installed then
	if command -v fzf &>/dev/null; then
		if test -e /usr/share/fzf/shell/key-bindings.zsh; then
			source /usr/share/fzf/shell/key-bindings.zsh
		fi
	fi

# IF we are Fedora
elif lsb_release -a 2>/dev/null | grep -qiE "Distributor\sID:\sFedora"; then
	# IF fzf is installed then
	if command -v fzf &>/dev/null; then
		if test -e /usr/share/fzf/shell/key-bindings.zsh; then
			source /usr/share/fzf/shell/key-bindings.zsh
		fi
	fi
# IF we are NixOS
elif lsb_release -a 2>/dev/null | grep -q "Distributor\sID:\sNixOS"; then
	if [ -n "${commands[fzf-share]}" ]; then
	  source "$(fzf-share)/key-bindings.zsh"
	  source "$(fzf-share)/completion.zsh"
	fi
else
	: # do nothing
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
	
	# Load fzf ZSH completion and key bindings
	if [ -f /usr/share/fzf/completion.zsh ]; then
		source /usr/share/fzf/completion.zsh
	fi

fi

# Catppuccin Mocha
# Define colors using Zsh's prompt expansion
COLOR1="%B%F{75}"    # Blue (User)
COLOR2="%B%F{176}"   # Bold Pink (Host)
COLOR3="%B%F{116}"   # Bold Teal (Directory)
COLOR4="%B%F{215}"   # Bold Yellow-Orange (@ symbol)
COLOR5="%B"          # Just Bold
COLOR6="%B%F{151}"   # Bold Green
COLOR7="%B%F{168}"   # Bold Red
RESET="%f%b"         # Reset formatting

# Add some nice git status to the prompt ONLY if git is installed
if command -v git &>/dev/null; then
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
			prompt="${prompt} ${behind_count}(Ahead)"
		fi
		if [ "$ahead_count" -gt 0 ]; then
			prompt="${prompt} ${ahead_count}(Behind)"
		fi

		# Return the prompt string
		echo -n "$prompt" ⇒
	}

	git_repo_name() {
		# Get the repository name by parsing the git remote URL
		git remote get-url origin 2>/dev/null | sed -E 's/.*[:\/]([^\/]+)\/([^\/]+).*/\2/'
	}
	
	# Set ZSH prompt (using PROMPT instead of PS1)
	NEWLINE=$'\n'
	precmd() { print -rP  $'$NEWLINE╭╴${COLOR1}%n${RESET}${COLOR4}@${RESET}${COLOR2}%m${RESET} ${COLOR3}%~${RESET} ${COLOR5}$(git_prompt) $(git_repo_name)${RESET}' }
	export PROMPT=$'╰─ ❯ '
else
	# Basic prompt without git info
	NEWLINE=$'\n'
	precmd() { print -rP  $'$NEWLINE╭╴${COLOR1}%n${RESET}${COLOR4}@${RESET}${COLOR2}%m${RESET} ${COLOR3}%~${RESET} ' }
	export PROMPT=$'╰─ ❯ '
fi

# IF lazygit is installed
if command -v lazygit &>/dev/null; then
	alias lg='lazygit'
fi

# Yazi config
# ONLY if yazi is installed standalone
if command -v yazi &>/dev/null; then
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
	# IF lazygit is installed
	if command -v lazygit &>/dev/null; then
		alias lg='lazygit'
	fi
	# Yazi config
	# ONLY if yazi is installed through brew
	if command -v yazi &>/dev/null; then
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
fi

# Carapace shell completion 
if command -v "carapace" &>/dev/null; then
	export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense,nu' # optional
	source <(carapace _carapace)
	# No errors if when tabbing on unknown flags
	export CARAPACE_LENIENT=1
fi



# ZSH specific settings


# Syntax highlighting (if available)
if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi


# Auto-suggestions (if available)
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# Enable ZSH features
setopt EXTENDED_HISTORY     # Record timestamp in history
setopt HIST_VERIFY          # Show command with history expansion before running it
setopt SHARE_HISTORY        # Share history between sessions
setopt APPEND_HISTORY       # Add commands to history immediately
setopt HIST_IGNORE_SPACE    # Don't store commands starting with space
setopt PROMPT_SUBST         # Allow parameter expansion, command substitution in prompts

# Enable colors
autoload -Uz colors
colors



# PROMPT if no vi-mode enabled

# IMPORTANT new line character: \n  needs to be wrapped for zsh like this:
# %{\n%}
# Update the prompt - replace %# with $PROMPT_SYMBOL

# precmd() for multiline to fix zsh prompt redraw issues
NEWLINE=$'\n'
precmd() { print -rP  $'$NEWLINE╭╴${COLOR1}%n${RESET}${COLOR4}@${RESET}${COLOR2}%m${RESET} ${COLOR3}%~${RESET} ${COLOR5}$(git_prompt) $(git_repo_name)${RESET}' }
# Change prompt indicator to RED if command was not successful
error_status_prompt_color() {
	if [[ $? -eq 0 || $? -eq 130 ]]; then
		export PROMPT=$'╰─ %{${COLOR6}%} ❯%{${RESET}%} '
	else 
		export PROMPT=$'╰─ %{${COLOR7}%} ❯%{${RESET}%} '
	fi
}
# Hook function into precmd so it runs before each prompt
autoload -Uz add-zsh-hook
add-zsh-hook precmd error_status_prompt_color	


if source ~/.config/zsh/plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh >/dev/null 2>&1  ; then
	# zsh-vi-mode plugin config
	## Escape key
	ZVM_VI_INSERT_ESCAPE_BINDKEY=ii
	ZVM_VI_ESCAPE_BINDKEY=ii
	ZVM_VI_VISUAL_ESCAPE_BINDKEY=ii
	# Surround with s key prefix
	# add surrounding quotes with sa"
	ZVM_VI_SURROUND_BINDKEY=s-prefix
	# Cursor in insert mode
	ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK

	# Source .fzf.zsh so that the ctrl+r bindkey is given back fzf
	# IF we are Ubuntu
	if lsb_release -a 2>/dev/null | grep -qiE "Distributor\sID:\sUbuntu"; then
		alias sudoedit='sudo -E -s $EDITOR'
		# IF fzf is installed then
		if command -v fzf &>/dev/null; then
			if test -e /usr/share/fzf/shell/key-bindings.zsh; then
				zvm_after_init_commands+=('
				  source /usr/share/fzf/shell/key-bindings.zsh
				')
			elif test -e /usr/share/doc/fzf/examples/key-bindings.zsh; then
				zvm_after_init_commands+=('
				  source /usr/share/doc/fzf/examples/key-bindings.zsh
				')
			fi
		fi

	# IF we are Debian
	elif lsb_release -a 2>/dev/null | grep -qiE "Distributor\sID:\sDebian"; then
		alias sudoedit='sudo -E -s $EDITOR'
		# IF fzf is installed then
		if command -v fzf &>/dev/null; then
			if test -e /usr/share/fzf/shell/key-bindings.zsh; then
				zvm_after_init_commands+=('
				  source /usr/share/fzf/shell/key-bindings.zsh
				')
			fi
		fi

	# IF we are Fedora
	elif lsb_release -a 2>/dev/null | grep -qiE "Distributor\sID:\sFedora"; then
		# IF fzf is installed then
		if command -v fzf &>/dev/null; then
			if test -e /usr/share/fzf/shell/key-bindings.zsh; then
				zvm_after_init_commands+=('
					source /usr/share/fzf/shell/key-bindings.zsh
				')
			fi
		fi
	# IF we are NixOS
	elif lsb_release -a 2>/dev/null | grep -q "Distributor\sID:\sNixOS"; then
		if [ -n "${commands[fzf-share]}" ]; then
		zvm_after_init_commands+=('
		  source "$(fzf-share)/key-bindings.zsh"
		  source "$(fzf-share)/completion.zsh"
		')
		fi
	else
		: # do nothing
	fi
	# This will auto execute this zvm_after_lazy_keybindings function
	# To avoid conflicts
	function zvm_after_lazy_keybindings() {
		# Don't enter edit-command-line with v in visual mode
		zvm_bindkey visual 'v' zvm_enter_visual_mode
		# Enter edit-command-line with Ctrl+e in normal mode
		zvm_bindkey vicmd '^e' zvm_vi_edit_command_line
		# Enter edit-command-line with Ctrl+e in visual mode
		zvm_bindkey visual '^e' zvm_vi_edit_command_line
	}

	# This block of code fixes the bug in zsh-vi-mode plugin where the $ZVM_MODE does not update
	# when using the 'c' vim motions like 'cw' 'ciw' 'cW' 'caw' etc.
	#### START
	function zvm_after_select_vi_mode() {
	  # Force redraw prompt when the vi mode changes
	  zle reset-prompt
	}

	# Add this handler to ensure change operations enter insert mode correctly
	function zvm_change_handler() {
	  # Make sure we're in insert mode after completing a change operation
	  zvm_select_vi_mode $ZVM_MODE_INSERT
	}

	# Register the change handler function with the plugin's hooks
	function zvm_after_init() {
	  # Hook into the various change operations
	  local original_widget
	  for cmd in vi-change{,-eol,-whole-line} vi-substitute{,-whole-line}; do
	    if (( $+widgets[$cmd] )); then
	      original_widget="${widgets[$cmd]#user:}"
	      zle -N $cmd zvm_change_handler
	    fi
	  done
	}
	#### END
	# export PROMPT=$'└─╼ [%{${COLOR4}%}${ZVM_MODE:u}%{${RESET}%}] %# '
	# export PROMPT=$'└─╼ ┌─ [%{${COLOR4}%}${ZVM_MODE:u}%{${RESET}%}] %# '

	# Change to RED if command was not successful
	error_status_prompt_color() {
		if [[ $? -eq 0 || $? -eq 130 ]]; then
			export PROMPT=$'╰─ [%{${COLOR4}%}${ZVM_MODE:u}%{${RESET}%}]%{${COLOR6}%} ❯%{${RESET}%} '
		else 
			export PROMPT=$'╰─ [%{${COLOR4}%}${ZVM_MODE:u}%{${RESET}%}]%{${COLOR7}%} ❯%{${RESET}%} '
		fi
	}
	# Hook function into precmd so it runs before each prompt
	autoload -Uz add-zsh-hook
	add-zsh-hook precmd error_status_prompt_color	
fi

# zsh syntax highlighting
source ~/.config/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

bindkey -M viins '^l' autosuggest-accept
bindkey -M viins '^Y' autosuggest-accept
bindkey -M vicmd 'L' end-of-line
bindkey -M vicmd 'H' beginning-of-line
# Don't need to use execute mode
do-nothing-zsh() {}
zle -N do-nothing-zsh
bindkey -M vicmd ':' do-nothing-zsh
bindkey -M vicmd '/' do-nothing-zsh
bindkey -M vicmd '?' do-nothing-zsh


HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

# Tab completion highlighting
zstyle ':completion:*' menu select
# Navigate completion list with vim keys
zmodload zsh/complist
# use the vi navigation keys in menu completion
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history

