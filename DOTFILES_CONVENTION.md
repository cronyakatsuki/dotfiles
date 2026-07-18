# Dotfiles Management Convention

## Structure
Each config is an **independent Stow package** at the top level of this repo.

```
~/dotfiles/
├── alacritty/   →  stow alacritty   →  ~/.config/alacritty/alacritty.toml
├── atuin/       →  stow atuin       →  ~/.config/atuin/config.toml
├── bin/         →  stow bin         →  ~/.local/bin/{safe-edit,pi-agent}
├── git/         →  stow git         →  ~/.config/git/config
├── htop/        →  stow htop        →  ~/.config/htop/htoprc
├── pi/          →  stow pi          →  ~/.pi/agent/extensions/
├── starship/    →  stow starship    →  ~/.config/starship.toml
├── tmux/        →  stow tmux        →  ~/.config/tmux/tmux.conf
├── user-dirs/   →  stow user-dirs   →  ~/.config/user-dirs.dirs
└── zsh/         →  stow zsh         →  ~/.config/zsh/.zshrc + completions/
```

## Package Rules
1. **One package = one config.** Each directory is a self-contained stow package.
2. **Full path from $HOME.** Files inside a package mirror their target location relative to `~`.
   - Example: `tmux/.config/tmux/tmux.conf` → `~/.config/tmux/tmux.conf`
3. **Install all:** `stow */` from `~/dotfiles`
4. **Install one:** `stow tmux` from `~/dotfiles`
5. **Remove:** `stow -D tmux` from `~/dotfiles`
6. **Default branch:** `main`

## Adding a New Config
1. Create a new directory: `mkdir -p <name>/.config/<name>/` (or appropriate path)
2. Place the config file inside following the `~` relative path
3. `stow <name>` to symlink it
4. `git add <name>/ && git commit -m "add: <name> config"`
