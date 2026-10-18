# dotfiles

Personal configuration files managed with [GNU Stow](https://www.gnu.org/software/stow/). See [DOTFILES_CONVENTION.md](DOTFILES_CONVENTION.md) for structure and rules.

## Packages

| Package | Description | Target |
|---|---|---|
| `atuin` | Shell history search & sync (self-hosted server) | `~/.config/atuin/config.toml` |
| `bat` | `bat` syntax-highlighted pager (Catppuccin Mocha theme) | `~/.config/bat/` |
| `bin` | CLI scripts (`safe-edit`, `pi-agent`) | `~/.local/bin/` |
| `btop` | System monitor (Catppuccin Mocha theme) | `~/.config/btop/` |
| `fastfetch` | System info tool | `~/.config/fastfetch/config.jsonc` |
| `fd` | File finder (ignore rules) | `~/.config/fd/ignore` |
| `ghostty` | Ghostty terminal (Monaspace font, tmux-focused, no toasts/overlays) | `~/.config/ghostty/config` |
| `git` | Git configuration | `~/.config/git/config` |
| `htop` | Process viewer | `~/.config/htop/htoprc` |
| `lazygit` | Git TUI | `~/.config/lazygit/config.yml` |
| `pi` | Pi agent extensions | `~/.pi/agent/extensions/` |
| `plasma` | KDE Plasma desktop layout (panel, applets) | `~/.config/plasma*` |
| `procs` | Modern `ps` replacement | `~/.config/procs/config.toml` |
| `ripgrep` | Search tool | `~/.config/ripgrep/rg.conf` |
| `starship` | Shell prompt | `~/.config/starship.toml` |
| `tmux` | Terminal multiplexer | `~/.config/tmux/tmux.conf` + theme |
| `user-dirs` | XDG user directories | `~/.config/user-dirs.dirs` |
| `vesktop` | Vesktop (Discord) settings | `~/.config/vesktop/settings/settings.json` |
| `yazi` | Terminal file manager (plugins, keymaps, theme) | `~/.config/yazi/` |
| `zen` | Zen Browser custom CSS (Catppuccin Mocha) | `~/.config/zen/main/chrome/` |
| `zsh` | Zsh shell (`conf.d/` split config + completions) | `~/.config/zsh/` |

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
