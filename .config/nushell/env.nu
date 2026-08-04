# ~/.config/nushell/env.nu

# =====================================
# PATH
# =====================================

let extra_paths = [
    $"($env.HOME)/.local/bin"
    $"($env.HOME)/bin"
    $"($env.HOME)/.cargo/bin"
    $"($env.HOME)/go/bin"
    $"($env.HOME)/.config/bashrc-plus"
]

$env.PATH = (
    $env.PATH
    | prepend $extra_paths
    | uniq
)


# =====================================
# Linuxbrew
# =====================================

let brew_path = "/home/linuxbrew/.linuxbrew/bin"

if ($brew_path | path exists) {
    $env.PATH = (
        $env.PATH
        | prepend $brew_path
        | uniq
    )
}


# =====================================
# Default editor
# =====================================

if (which nvim | is-not-empty) {
    $env.EDITOR = "nvim"
    $env.VISUAL = "nvim"
    $env.SUDO_EDITOR = "nvim"
} else if (which vim | is-not-empty) {
    $env.EDITOR = "vim"
    $env.VISUAL = "vim"
    $env.SUDO_EDITOR = "vim"
}


# =====================================
# bat pager / man pages
# =====================================

if (which bat | is-not-empty) {

    $env.PAGER = "bat --paging=always --style=plain"

    $env.MANROFFOPT = "-c"

    $env.MANPAGER = "bash -c 'col -bx | bat -l man -p'"
}


# =====================================
# fzf
# =====================================

let current_fzf = ($env.FZF_DEFAULT_OPTS? | default "")

if not ($current_fzf | str contains "ctrl-y:accept") {
    $env.FZF_DEFAULT_OPTS = (
        $"--bind=ctrl-y:accept ($current_fzf)"
    )
}


# =====================================
# Carapace
# =====================================

if (which carapace | is-not-empty) {

    $env.CARAPACE_BRIDGES = (
        "zsh,fish,bash,inshellisense,nu"
    )

    $env.CARAPACE_LENIENT = "1"
}


# =====================================
# Systemd pager
# =====================================

# Uncomment if you dislike systemctl paging
# $env.SYSTEMD_PAGER = ""


# =====================================
# Nushell history
# =====================================

$env.config = (
    $env.config?
    | default {}
    | merge {
        history: {
            file_format: "sqlite"
            max_size: 100000
            sync_on_enter: true
        }
    }
)

