# Dependencies

install with whatever package manager

Fedora
```bash
sudo dnf install git stow unzip fzf fd-find ripgrep make automake gcc gcc-c++ -y
```
Ubuntu
```bash
sudo apt install git stow gcc build-essential unzip fzf fd-find ripgrep -y
```

# Download repo with submodules

```bash
git clone --recurse-submodules --remote-submodules https://github.com/SuperSweatyYeti/dotfiles.git ~/dotfiles
```

# Install

```bash
cd ~/dotfiles
# Init and download the submodules
git submodule update --init --recursive
# Checkout the master branches for each submodule
# Is this needed?
cd ~/dotfiles/.config/nvim
git checkout master
cd ~/dotfiles/.config/tmux/plugins/tmp
git checkout master
```

# Other Recommended dependencies to install

Install brew for other apps like [ yazi ]( https://github.com/sxyazi/yazi  )( Best terminal file manager right now )

[ Home Brew Website ](https://brew.sh/)

# After brew installed

```bash
source ~/.bashrc
brew install yazi 
source ~/.bashrc
```
# Neovim plugin dependencies

## Copilot

Need to Install nodejs

