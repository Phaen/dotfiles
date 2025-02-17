# Dotfiles
My personal cross-machine Linux/Mac configuration.

## Index
Currently covers the following:
 - nvim
 - kitty
 - oh-my-zsh
   
## Setup

### With chezmoi installed (read/write)
```bash
chezmoi init git@github.com:Phaen/dotfiles.git
```
### Without chezmoi installed (read-only)
```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply Phaen
```

### Without chezmoi installed (one-shot)
```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --one-shot Phaen
```
## Details

### TheFuck
The oh-my-zsh config contains aliases for thefuck. If you don't have it installed and want to do so through a local pip, make sure you install setuptools too.
`pip install setuptools thefuck`
