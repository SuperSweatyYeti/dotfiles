#!/bin/bash

# Setup keyd config
echo "Setting up keyd config file..."
sudo mkdir -p /etc/keyd
sudo cp ~/dotfiles/keyd.conf /etc/keyd/default.conf

# Setup tmux plugin manager
echo "Git cloning tmux plugin manager"
git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm

