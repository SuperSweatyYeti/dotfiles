# Dependencies

git
stow
gcc

install with whatever package manager

Fedora
```bash
sudo dnf install git stow gcc unzip fzf fd-find ripgrep -y
```
Ubuntu
```bash
sudo apt install git stow gcc build-essentials unzip fzf fd-find ripgrep -y
```

# Download repo

```bash
git clone https://github.com/SuperSweatyYeti/dotfiles.git ~/dotfiles
```

# Install

```bash
cd ~/dotfiles
stow . --ignore="setup\.sh"
git submodule init
git submodule update
cd ~/dotfiles/.config/nvim
git checkout master
```

# Other Recommended dependencies to install

```bash
sudo dnf install fzf fd-find ripgrep
```

Install brew for other apps like [ yazi ]( https://github.com/sxyazi/yazi  )( Best terminal file manager right now )

[ Home Brew Website ](https://brew.sh/)
