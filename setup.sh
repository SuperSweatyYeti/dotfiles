#!/bin/bash

# Pre-create all required parent directories in $HOME
# This scans the dotfiles repo for directories and mirrors them in ~
# so that `stow --adopt` doesn't fail on missing paths.
cd ~/dotfiles || exit
find . -type d \
  ! -path './.git' \
  ! -path './.git/*' \
  -exec mkdir -p "$HOME/{}" \;

# Init and download submodules
git submodule update --init --recursive

# Checkout master branches for submodules
cd ~/dotfiles/.config/nvim || exit
git checkout master

cd ~/dotfiles/.config/tmux/plugins/tpm || exit
git checkout master

# Setup tmux plugin manager (skip if already cloned via submodule)
if [ ! -d ~/.config/tmux/plugins/tpm ]; then
  git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
fi

# Symlink entire directories so new files are immediately tracked by git
# -s = symbolic link, -f = force overwrite, -n = don't follow existing dir
ln -sfn ~/dotfiles/.config/nvim ~/.config/nvim
ln -sfn ~/dotfiles/.config/putty ~/.config/putty
ln -sfn ~/dotfiles/.config/rmpc ~/.config/rmpc
ln -sfn ~/dotfiles/.config/yazi ~/.config/yazi
ln -sfn ~/dotfiles/.config/rio ~/.config/rio
ln -sfn ~/dotfiles/.config/tmux ~/.config/tmux

# User Bash scripts
# Create directory if it does not exist
bash_completion_dir="$HOME/.local/share/bash-completion/completions"
mkdir -p "$bash_completion_dir"

nmcli_try_completions_file="$HOME/.config/bashrc-plus/nmcli-try-completions"

cp "$nmcli_try_completions_file" "$bash_completion_dir"

# Setup keyd config
sudo mkdir -p /etc/keyd
sudo ln -sf ~/dotfiles/keyd.conf /etc/keyd/default.conf

# Setup tailscale prefer local routes when overlapping fix
# TODO
echo "Setting up tailscale prefer local routes systemd service.."
sudo mkdir -p /etc/tailscale
sudo cp ~/dotfiles/tailscale-prefer-local-routes/90-tailscale-prefer-local-routes /etc/NetworkManager/dispatcher.d/90-tailscale-prefer-local-routes 
sudo cp ~/dotfiles/tailscale-prefer-local-routes/tailscale-prefer-local-routes.sh /etc/tailscale/tailscale-prefer-local-routes.sh
sudo cp ~/dotfiles/tailscale-prefer-local-routes/tailscale-prefer-local-routes.service /etc/systemd/system/tailscale-prefer-local-routes.service
sudo cp ~/dotfiles/tailscale-prefer-local-routes/tailscale-prefer-local-routes.timer /etc/systemd/system/tailscale-prefer-local-routes.timer
sudo cp ~/dotfiles/tailscale-prefer-local-routes/tailscale-prefer-local-routes.timer /etc/systemd/system/tailscale-prefer-local-routes.timer

sudo systemctl daemon-reload
sudo systemctl enable --now tailscale-prefer-local-routes.service

# Now stow is safe to run
cd ~/dotfiles || exit
stow . --adopt
