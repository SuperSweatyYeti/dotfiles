# ~/.config/nushell/config.nu



# =====================================
# Aliases
# =====================================

# Generate machine-specific aliases
source ~/.config/nushell/gen-aliases.nu

# Load generated aliases
source ~/.config/nushell/aliases.nu


# =====================================
# Functions
# =====================================

# =====================================
# rmpc
# =====================================

if (which rmpc | is-not-empty) {

    def rmpc-noart [] {
        rmpc -c $"($env.HOME)/.config/rmpc/config-noart.ron"
    }

}


# =====================================
# Volume helpers
# =====================================

if (which wpctl | is-not-empty) {

    def vol-up [] {
        ^wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
    }


    def vol-down [] {
        ^wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    }


    def vol-set [percent:int] {

        if $percent < 0 or $percent > 100 {
            error make {
                msg: "Volume must be between 0 and 100"
            }
        }

        let value = (($percent | into float) / 100)

        ^wpctl set-volume @DEFAULT_AUDIO_SINK@ $value
    }
}



# =====================================
# Obsidian sync
# =====================================

if (which ob | is-not-empty) {

    def obsync-status [] {
        ^ob sync-status
    }


    def obsync-now [] {
        ^ob sync
    }


    def obsync-continuous [] {
        ^ob sync --continuous
    }


    def ob-sync-config-custom [] {

        ^ob sync-config --file-types "image,audio,video,pdf,unsupported"

        ^ob sync-config --configs "app,appearance,appearance-data,hotkey,core-plugin,core-plugin-data,community-plugin,community-plugin-data"
    }

}



# =====================================
# cheat.sh
# =====================================

if (which curl | is-not-empty) {

    def cheatsh [command:string] {

        ^curl -s $"https://cheat.sh/($command)"
    }

}



# =====================================
# Yazi
# =====================================

if (which yazi | is-not-empty) {


    alias y = yazi


    def --env cdyazi [...args] {

        let tmp = (^mktemp)


        ^yazi ...$args --cwd-file $tmp


        let cwd = (
            open $tmp
            | str trim
        )


        rm $tmp


        if ($cwd != "") and ($cwd != $env.PWD) {
            cd $cwd
        }
    }


    alias cdy = cdyazi

}



# =====================================
# Git prompt
# =====================================

# Get rid of right side date in prompt
$env.PROMPT_COMMAND_RIGHT = {|| "" }

def git_prompt [] {

    let inside = (
        ^git rev-parse --is-inside-work-tree
        err> /dev/null
        | complete
    )

    if $inside.exit_code != 0 {
        return ""
    }

    let branch = (
        ^git branch --show-current
        | complete
        | get stdout
        | str trim
    )

    let status = (
        ^git status --porcelain
        | complete
        | get stdout
        | lines
    )

    let modified = (
        $status
        | where ($it | str starts-with " M")
        | length
    )

    let staged = (
        $status
        | where ($it | str starts-with "M ")
        | length
    )

    let dirty = (
        if ($status | length) > 0 {
            $"(ansi yellow)"
        } else {
            $"(ansi green)"
        }
    )

    mut result = $" ($dirty) ($branch)"

    if $modified > 0 {
        $result = $"($result) ($modified)󰷉"
    }

    if $staged > 0 {
        $result = $"($result) ($staged)✔"
    }

    $"($result)(ansi reset)"
}


# =====================================
# Python virtualenv prompt
# =====================================

def python_prompt [] {

    if ("VIRTUAL_ENV" in $env) {

        let name = (
            $env.VIRTUAL_ENV
            | path basename
        )

        $"(ansi cyan)($name)(ansi reset) "
    }

}



# =====================================
# Main prompt
# =====================================

$env.PROMPT_COMMAND = {||

    let user = $"(ansi cyan)($env.USER)(ansi reset)"

    let host = (
        $"(ansi magenta)((sys host | get hostname))(ansi reset)"
    )

    let dir = (
        $"(ansi blue)(pwd)(ansi reset)"
    )


    $"\n(ansi white)╭╴(ansi reset)($user)(ansi yellow)@(ansi reset)($host) ($dir)(git_prompt)\n╰─ (python_prompt)"
}



$env.PROMPT_INDICATOR = {||
    $"(ansi green)\(nu\)(ansi reset) ❯ "
}


$env.PROMPT_INDICATOR_VI_INSERT = {||
    $"(ansi green)\(nu\)(ansi reset) (ansi green)[I](ansi reset) ❯ "
}

$env.PROMPT_INDICATOR_VI_NORMAL = {||
    $"(ansi green)\(nu\)(ansi reset) (ansi yellow)[N](ansi reset) ❯ "
}



# =====================================
# fzf helpers
# =====================================

if (which fzf | is-not-empty) {


    def fz [] {

        ^fzf --ansi
    }



    def rfz [] {

        ^rg --column --color=always --smart-case ""
        | ^fzf --ansi
    }


    def cdfz [] {

        let dir = (
            ^find . -type d
            | ^fzf
        )

        if $dir != "" {
            cd $dir
        }
    }

}

# =====================================
# Keybinds
# =====================================

$env.config.keybindings ++= [
  {
    name: accept_suggestion_ctrl_y
    modifier: control
    keycode: char_y
    mode: [emacs vi_insert vi_normal]
    event: { send: HistoryHintComplete }
  }
]

$env.config.edit_mode = "vi"

# =====================================
# KDE logout
# =====================================

if (which kde-open | is-not-empty) {

    def kdelogout [] {
        ^qdbus org.kde.Shutdown /Shutdown logout
    }

}



# =====================================
# Extra Nushell configs
# =====================================

# Files in ~/.config/nushell/conf.d/
# are automatically loaded by Nushell.
#zoxide init nushell | save -f ~/.config/nushell/zoxide.nu

source ~/.config/nushell/zoxide.nu

