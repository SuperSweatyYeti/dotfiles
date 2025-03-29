# Dependencies

git
stow
gcc

install with whatever package manager
```bash
sudo dnf install git stow gcc
```

# Download repo

```bash
git clone https://github.com/SuperSweatyYeti/dotfiles.git ~/dotfiles
```

# Install

```bash
cd ~/dotfiles
stow . --ignore="setup\.sh"
```

# Other Recommended dependencies to install

```bash
sudo dnf install fzf fd-find ripgrep
```

Install brew for other apps like [ yazi ]( https://github.com/sxyazi/yazi  )( Best terminal file manager right now )

[ Home Brew Website ](https://brew.sh/)
