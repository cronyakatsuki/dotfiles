# dotfiles

Personal configuration files managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Packages

| Package | Description | Target |
|---|---|---|
| `alacritty` | Alacritty terminal emulator | `~/.config/alacritty/alacritty.toml` |
| `atuin` | Shell history search | `~/.config/atuin/config.toml` |
| `bin` | CLI scripts | `~/.local/bin/safe-edit` |
| `git` | Git configuration | `~/.config/git/config` |
| `htop` | Htop configuration | `~/.config/htop/htoprc` |
| `pi` | Pi agent extensions | `~/.pi/agent/extensions/` |
| `starship` | Starship prompt | `~/.config/starship.toml` |
| `tmux` | Tmux configuration | `~/.config/tmux/tmux.conf` |
| `user-dirs` | XDG user directories | `~/.config/user-dirs.dirs` |
| `zsh` | Zsh shell configuration | `~/.config/zsh/.zshrc` + completions |

## Usage

```bash
# Clone and install all packages
git clone https://git.cronyakatsuki.xyz/crony/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow */

# Or install individual packages
stow tmux          # only tmux config
stow starship git  # specific combination

# Remove symlinks
stow -D tmux
```

## Requirements

- [GNU Stow](https://www.gnu.org/software/stow/) — for symlink management
- [Pi](https://github.com/earendil-works/pi) — AI coding assistant (optional, for pi extensions)

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).
