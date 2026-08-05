#!/usr/bin/env nu

let file = $"($nu.default-config-dir)/aliases.nu"

def save-alias [...args: string] {
    $"alias ($args | str join ' ')\n" | save -a $file
}

# Clear generated aliases
'' | save -f $file


if not (which nvim | is-empty) {
    save-alias "vim" "=" "nvim"
}


if not (which lazygit | is-empty) {
    save-alias "lg" "=" "lazygit"
}


# Regular aliases

alias ll = ls -al


