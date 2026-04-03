# .zshrc
# User specific environment
if [[ ! "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Add cargo/rust binaries to path
CARGO_BIN_PATH="$HOME/.cargo/bin"
if [[ ! "$PATH" =~ "$CARGO_BIN_PATH" ]]; then
    PATH="$CARGO_BIN_PATH:$PATH"
fi
export PATH

# Add go binaries to path
GO_BIN_PATH="$HOME/go/bin"
if [[ ! "$PATH" =~ "$GO_BIN_PATH" ]]; then
    PATH="$GO_BIN_PATH:$PATH"
fi
export PATH


# alias for rmpc ( Terminal music player ) launch with
# no album art config
if command -v rmpc &>/dev/null; then
  alias rmpc-noart="rmpc -c '$HOME/.config/rmpc/config-noart.ron'"
fi

# aliases for obsidian headless sync
if command -v ob &>/dev/null; then
    # Sync status
    alias obsync-status="ob sync-status"
    # Run a one-time sync
    alias obsync-now="ob sync"
    # Run continuous sync (watches for changes)
    alias obsync-continuous="ob sync --continuous"
    function ob-sync-config-custom(){
        # Setup obsidian sync cli config options
        ob sync-config --file-types "image,audio,video,pdf,unsupported"
        ob sync-config --configs "app,appearance,appearance-data,hotkey,core-plugin,core-plugin-data,community-plugin,community-plugin-data"
    }
fi

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
    unbuffer "$@"
  elif command -v stdbuf &>/dev/null; then
    stdbuf -i0 -o0 -e0 "$@"
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

# Clear print jobs
if command -v cancel &>/dev/null; then
    function print-clear(){
        # Cancel jobs
        cancel -a
        sudo systemctl restart cups.service
    }
fi


# Set Syntax highlighting for man pages with bat
# Set bat as default pager
if command -v bat &>/dev/null; then
    # Fix weird escape characters for man pages
    export MANROFFOPT='-c'
    export MANPAGER="bash -c 'col -bx | bat -l man -p'"
    # Set bat as default pager
    export PAGER="bat --paging=always"
fi

########################################################
# Switch display managers either sddm or gdm
########################################################
switchdm-gdm() {
  local GDMservice="gdm.service"
  local SDDMservice="sddm.service"

  service_exists() {
    local svc="$1"
    [[ "$(systemctl show -p LoadState --value "$svc" 2>/dev/null || true)" != "not-found" ]]
  }

  is_enabled() {
    local svc="$1"
    systemctl is-enabled "$svc" >/dev/null 2>&1
  }

  is_active() {
    local svc="$1"
    systemctl is-active "$svc" >/dev/null 2>&1
  }

  if ! service_exists "$GDMservice"; then
    echo "$GDMservice does not exist."
    return 1
  fi

  # Already on gdm (enabled + active)
  if is_enabled "$GDMservice" && is_active "$GDMservice"; then
    echo "$GDMservice is already enabled and active."
    return 0
  fi

  # If sddm exists and is enabled/active, turn it off first
  if service_exists "$SDDMservice"; then
    if is_active "$SDDMservice"; then
      sudo systemctl stop "$SDDMservice"
    fi
    if is_enabled "$SDDMservice"; then
      sudo systemctl disable "$SDDMservice"
    fi
  fi

  sudo systemctl enable "$GDMservice"
  sudo systemctl start "$GDMservice"

  echo "Switched to $GDMservice."
  echo "If needed: sudo systemctl restart display-manager"
}

switchdm-sddm() {
  local GDMservice="gdm.service"
  local SDDMservice="sddm.service"

  service_exists() {
    local svc="$1"
    [[ "$(systemctl show -p LoadState --value "$svc" 2>/dev/null || true)" != "not-found" ]]
  }

  is_enabled() {
    local svc="$1"
    systemctl is-enabled "$svc" >/dev/null 2>&1
  }

  is_active() {
    local svc="$1"
    systemctl is-active "$svc" >/dev/null 2>&1
  }

  if ! service_exists "$SDDMservice"; then
    echo "$SDDMservice does not exist."
    return 1
  fi

  # Already on sddm (enabled + active)
  if is_enabled "$SDDMservice" && is_active "$SDDMservice"; then
    echo "$SDDMservice is already enabled and active."
    return 0
  fi

  # If gdm exists and is enabled/active, turn it off first
  if service_exists "$GDMservice"; then
    if is_active "$GDMservice"; then
      sudo systemctl stop "$GDMservice"
    fi
    if is_enabled "$GDMservice"; then
      sudo systemctl disable "$GDMservice"
    fi
  fi

  sudo systemctl enable "$SDDMservice"
  sudo systemctl start "$SDDMservice"

  echo "Switched to $SDDMservice."
  echo "If needed: sudo systemctl restart display-manager"
}



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
    alias sudoedit='sudo XDG_CONFIG_HOME="$HOME/.config" $EDITOR'
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

if command -v kde-open &>/dev/null; then
    alias kdelogout="qdbus org.kde.Shutdown /Shutdown logout"
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

    alias cdfz='cd $(find . -type d -print | fzf  ) '
    
    # Load fzf ZSH completion and key bindings
    if [ -f /usr/share/fzf/completion.zsh ]; then
        source /usr/share/fzf/completion.zsh
    fi

fi

# Disable default ZSH prompt seperator character on outputs that don't end with newline
unsetopt PROMPT_SP

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


# ── Chezmoi Background Job + Functions ───────────────────────────────
# All chezmoi functions are wrapped in this check.
# If chezmoi is not installed, none of these functions are defined
# and the prompt segment is a no-op.
CHEZMOI_INSTALLED=0
if command -v chezmoi &>/dev/null; then
    CHEZMOI_INSTALLED=1
    alias cmoi='chezmoi'

    cmoicd() {
        local chezmoi_dir="$HOME/.local/share/chezmoi"
        [[ -d "$chezmoi_dir" ]] && cd "$chezmoi_dir"
    }

    cmoisync() {
        local chezmoi_dir="$HOME/.local/share/chezmoi"
        [[ -d "$chezmoi_dir" ]] || return

        git -C "$chezmoi_dir" add -A
        if [[ -z "$(git -C "$chezmoi_dir" status --porcelain)" ]]; then
            echo "\033[90mcmoisync: nothing to commit, already up to date.\033[0m"
            return
        fi
        git -C "$chezmoi_dir" commit -m "update $(date '+%Y-%m-%d %H:%M:%S')"
        git -C "$chezmoi_dir" push --force
    }

    # -- Watched folders for unmanaged file detection -----
    CHEZMOI_WATCHED_FOLDERS=(
        # "$HOME/.config/yazi"
        # Add more folders here:
        # "$HOME/.config/some-app"
    )

    # -- Cache (read by prompt — zero cost) -----
    CHEZMOI_STATUS_CACHE=""
    CHEZMOI_UNMANAGED_CACHE=()
    CHEZMOI_UNMANAGED_COUNT=0

    # -- Background job state -----
    CHEZMOI_BG_PID=0
    CHEZMOI_LAST_CHECK=0
    CHEZMOI_CHECK_INTERVAL=30
    CHEZMOI_TMPFILE="/tmp/.chezmoi_bg_result.$$"
    CHEZMOI_CHECK_ENABLED=1

    enable_chezmoi_check()  { CHEZMOI_CHECK_ENABLED=1; echo "Chezmoi check ON" }
    disable_chezmoi_check() { CHEZMOI_CHECK_ENABLED=0; echo "Chezmoi check OFF" }

    # -- Background worker (non-blocking) -----
    _chezmoi_bg_check() {
        (( CHEZMOI_CHECK_ENABLED )) || return

        # Don't stack — check if previous is still running
        if (( CHEZMOI_BG_PID > 0 )) && kill -0 "$CHEZMOI_BG_PID" 2>/dev/null; then
            return
        fi

        # Cooldown
        local now
        now=$(date +%s)
        if (( now - CHEZMOI_LAST_CHECK < CHEZMOI_CHECK_INTERVAL )); then
            return
        fi

        # Launch disowned background subshell
        {
            local tmpfile="$CHEZMOI_TMPFILE"
            local cz_status
            cz_status=$(chezmoi status 2>/dev/null)

            local unmanaged=""
            for folder in "${CHEZMOI_WATCHED_FOLDERS[@]}"; do
                [[ -d "$folder" ]] || continue
                local files
                files=$(chezmoi unmanaged "$folder" 2>/dev/null)
                if [[ -n "$files" ]]; then
                    if [[ -n "$unmanaged" ]]; then
                        unmanaged="${unmanaged}"$'\n'"${files}"
                    else
                        unmanaged="$files"
                    fi
                fi
            done

            # Atomic write via temp + mv
            local tmp_write="${tmpfile}.writing"
            {
                echo "STATUS_START"
                echo "$cz_status"
                echo "STATUS_END"
                echo "UNMANAGED_START"
                echo "$unmanaged"
                echo "UNMANAGED_END"
            } > "$tmp_write"
            mv -f "$tmp_write" "$tmpfile"
        } &!

        CHEZMOI_BG_PID=$!
    }

    # -- Collect results from background job (instant) -----
    _chezmoi_collect_result() {
        [[ -f "$CHEZMOI_TMPFILE" ]] || return

        # Still running? Don't read partial results
        if (( CHEZMOI_BG_PID > 0 )) && kill -0 "$CHEZMOI_BG_PID" 2>/dev/null; then
            return
        fi

        local in_status=0 in_unmanaged=0
        local status_lines="" unmanaged_lines=""

        while IFS= read -r line; do
            case "$line" in
                STATUS_START)    in_status=1; continue ;;
                STATUS_END)      in_status=0; continue ;;
                UNMANAGED_START) in_unmanaged=1; continue ;;
                UNMANAGED_END)   in_unmanaged=0; continue ;;
            esac
            if (( in_status )); then
                [[ -n "$line" ]] && status_lines="${status_lines:+${status_lines}$'\n'}${line}"
            elif (( in_unmanaged )); then
                [[ -n "$line" ]] && unmanaged_lines="${unmanaged_lines:+${unmanaged_lines}$'\n'}${line}"
            fi
        done < "$CHEZMOI_TMPFILE"

        CHEZMOI_STATUS_CACHE="$status_lines"
        if [[ -n "$unmanaged_lines" ]]; then
            CHEZMOI_UNMANAGED_CACHE=("${(@f)unmanaged_lines}")
            CHEZMOI_UNMANAGED_COUNT=${#CHEZMOI_UNMANAGED_CACHE[@]}
        else
            CHEZMOI_UNMANAGED_CACHE=()
            CHEZMOI_UNMANAGED_COUNT=0
        fi

        CHEZMOI_LAST_CHECK=$(date +%s)
        rm -f "$CHEZMOI_TMPFILE"
        CHEZMOI_BG_PID=0
    }

    # -- Synchronous helper (used by cmoistatus/cmoireadd) -----
    _get_chezmoi_unmanaged() {
        local all_unmanaged=""
        for folder in "${CHEZMOI_WATCHED_FOLDERS[@]}"; do
            [[ -d "$folder" ]] || continue
            local files
            files=$(chezmoi unmanaged "$folder" 2>/dev/null)
            if [[ -n "$files" ]]; then
                if [[ -n "$all_unmanaged" ]]; then
                    all_unmanaged="${all_unmanaged}"$'\n'"${files}"
                else
                    all_unmanaged="$files"
                fi
            fi
        done

        # Update cache
        if [[ -n "$all_unmanaged" ]]; then
            CHEZMOI_UNMANAGED_CACHE=("${(@f)all_unmanaged}")
            CHEZMOI_UNMANAGED_COUNT=${#CHEZMOI_UNMANAGED_CACHE[@]}
        else
            CHEZMOI_UNMANAGED_CACHE=()
            CHEZMOI_UNMANAGED_COUNT=0
        fi
        CHEZMOI_LAST_CHECK=$(date +%s)

        echo "$all_unmanaged"
    }

    cmoistatus() {
        echo "\033[36m── Chezmoi Status ──\033[0m"
        local cz_status
        cz_status=$(chezmoi status 2>/dev/null)
        CHEZMOI_STATUS_CACHE="$cz_status"
        if [[ -n "$cz_status" ]]; then
            echo "$cz_status"
        else
            echo "  \033[90m(no changes)\033[0m"
        fi

        echo ""

        echo "\033[36m── Unmanaged Files in Watched Folders ──\033[0m"
        local unmanaged
        unmanaged=$(_get_chezmoi_unmanaged)
        if [[ -n "$unmanaged" ]]; then
            while IFS= read -r file; do
                echo "  \033[31m+ $file\033[0m"
            done <<< "$unmanaged"
            echo ""
            echo "  \033[33m${CHEZMOI_UNMANAGED_COUNT} unmanaged file(s) found.\033[0m"
            echo "  \033[90mRun \033[32mcmoireadd\033[90m to re-add tracked changes and add these files.\033[0m"
        else
            echo "  \033[90m(all watched folders fully tracked)\033[0m"
        fi
    }

    cmoireadd() {
        echo "\033[36m── Re-adding tracked files ──\033[0m"
        chezmoi re-add
        echo "  \033[32mDone.\033[0m"

        echo ""

        echo "\033[36m── Adding unmanaged files from watched folders ──\033[0m"
        local unmanaged
        unmanaged=$(_get_chezmoi_unmanaged)
        if [[ -n "$unmanaged" ]]; then
            local added=0
            while IFS= read -r file; do
                local fullpath="$HOME/$file"
                if [[ -e "$fullpath" ]]; then
                    echo "  \033[32m+ $file\033[0m"
                    chezmoi add "$fullpath"
                    (( added++ ))
                else
                    echo "  \033[33m✗ $file (not found, skipping)\033[0m"
                fi
            done <<< "$unmanaged"
            echo ""
            echo "  \033[32m${added} file(s) added to chezmoi.\033[0m"
        else
            echo "  \033[90m(no unmanaged files found)\033[0m"
        fi

        # Clear cache
        CHEZMOI_UNMANAGED_CACHE=()
        CHEZMOI_UNMANAGED_COUNT=0
        CHEZMOI_STATUS_CACHE=""
    }

    # -- Prompt segment (called inside precmd's print) -----
    _chezmoi_prompt_segment() {
        local seg=""
        if (( CHEZMOI_CHECK_ENABLED )); then
            [[ -n "$CHEZMOI_STATUS_CACHE" ]] && seg+=" %F{yellow}🏠±%f"
            (( CHEZMOI_UNMANAGED_COUNT > 0 )) && seg+=" %F{red}📁+${CHEZMOI_UNMANAGED_COUNT}%f"
        fi
        echo -n "$seg"
    }

    # -- Hook: collect results + kick off next check -----
    _chezmoi_precmd_hook() {
        _chezmoi_collect_result
        _chezmoi_bg_check
    }
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _chezmoi_precmd_hook

    # -- Cleanup temp file on shell exit -----
    zshexit() {
        rm -f "$CHEZMOI_TMPFILE" "${CHEZMOI_TMPFILE}.writing"
    }
fi
# ── End Chezmoi ──────────────────────────────────────────────────────


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
        prompt="${color} ${branch}${RESET}"

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
fi

# IF lazygit is installed
if command -v lazygit &>/dev/null; then
    alias lg='lazygit'
fi
# IF lazydocker is installed
if command -v lazydocker &>/dev/null; then
    alias ldoc='lazydocker'
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
    # IF lazydocker is installed
    if command -v lazydocker &>/dev/null; then
        alias ldoc='lazydocker'
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

# Need to put this section after BREW in case neovim 
# is installed via homebrew
# Set default editor
if command -v nvim &>/dev/null; then
    alias vim='nvim'
    EDITOR='nvim'
    SUDO_EDITOR='nvim'
elif command -v vim &>/dev/null; then
    EDITOR='vim'
    SUDO_EDITOR='vim'
fi



# ZSH specific settings


# Syntax highlighting (if available)
if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi


# Auto-suggestions (if available)
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
elif [ -f ~/.config/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source ~/.config/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# Enable ZSH features
setopt EXTENDED_HISTORY     # Record timestamp in history
# setopt HIST_VERIFY          # Show command with history expansion before running it
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

# Python venv status for prompt
python_venv_prompt() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo -n "(%F{cyan}$(basename "$VIRTUAL_ENV")%f) "
    fi
}

# ── Prompt Extra Segments (chezmoi, etc.) ────────────────────────────
# Single function that collects all optional prompt segments.
# Called via $(…) in precmd. If chezmoi isn't installed, this is empty.
_prompt_extra_segments() {
    if (( CHEZMOI_INSTALLED )) ; then
        _chezmoi_prompt_segment
    fi
}

# precmd() for multiline to fix zsh prompt redraw issues
NEWLINE=$'\n'
if command -v git &>/dev/null; then
    precmd() { print -rP $'$NEWLINE╭╴${COLOR1}%n${RESET}${COLOR4}@${RESET}${COLOR2}%m${RESET} ${COLOR3}%~${RESET} ${COLOR5}$(git_prompt) $(git_repo_name)${RESET}$(_prompt_extra_segments)' }
else
    precmd() { print -rP $'$NEWLINE╭╴${COLOR1}%n${RESET}${COLOR4}@${RESET}${COLOR2}%m${RESET} ${COLOR3}%~${RESET}$(_prompt_extra_segments)' }
fi

# Change prompt indicator to RED if command was not successful
error_status_prompt_color() {
    if [[ $? -eq 0 || $? -eq 130 ]]; then
        export PROMPT=$'╰─ $(python_venv_prompt)%{${COLOR6}%} ❯%{${RESET}%} '
    else 
        export PROMPT=$'╰─ $(python_venv_prompt)%{${COLOR7}%} ❯%{${RESET}%} '
    fi
}
# Hook function into precmd so it runs before each prompt
autoload -Uz add-zsh-hook
add-zsh-hook precmd error_status_prompt_color    


if source ~/.config/zsh/plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh >/dev/null 2>&1  ; then
    # zsh-vi-mode plugin config
    ## Escape key
    ZVM_VI_INSERT_ESCAPE_BINDKEY=JJ
    ZVM_VI_ESCAPE_BINDKEY=JJ
    ZVM_VI_VISUAL_ESCAPE_BINDKEY=JJ
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

    # Change to RED if command was not successful
    error_status_prompt_color() {
        if [[ $? -eq 0 || $? -eq 130 ]]; then
            export PROMPT=$'╰─ $(python_venv_prompt)[%{${COLOR4}%}${ZVM_MODE:u}%{${RESET}%}]%{${COLOR6}%} ❯%{${RESET}%} '
        else 
            export PROMPT=$'╰─ $(python_venv_prompt)[%{${COLOR4}%}${ZVM_MODE:u}%{${RESET}%}]%{${COLOR7}%} ❯%{${RESET}%} '
        fi
    }
    # Hook function into precmd so it runs before each prompt
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd error_status_prompt_color    
fi

# fzf default keybinds use ctrl-y to accept
if [[ ! "$FZF_DEFAULT_OPTS" =~ "--bind=ctrl-y:accept" ]]; then
    FZF_DEFAULT_OPTS="--bind=ctrl-y:accept ${FZF_DEFAULT_OPTS}"
fi
export FZF_DEFAULT_OPTS

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
bindkey -M menuselect '^Y' accept-search


# zoxide config
if command -v rmpc &>/dev/null; then
  # To initialize zoxide, add this to your shell configuration file (usually ~/.zshrc):
  eval "$(zoxide init zsh)"
fi

