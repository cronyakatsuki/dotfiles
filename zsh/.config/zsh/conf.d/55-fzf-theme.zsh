# 55-fzf-theme.zsh — Catppuccin Mocha Lavender for fzf + default behavior
# Theme lives in ~/.config/fzf/default-opts (single source of truth, shared
# with tmux via FZF_DEFAULT_OPTS_FILE so run-shell popups get it too —
# the tmux server env has no FZF_DEFAULT_OPTS when started detached).
export FZF_DEFAULT_OPTS_FILE="$HOME/.config/fzf/default-opts"

# Ctrl-T: files only, dotfiles included, no ./ prefix (global fd ignore applies)
export FZF_CTRL_T_COMMAND='fd --type f --hidden --strip-cwd-prefix'
# Alt-C: directories only
export FZF_ALT_C_COMMAND='fd --type d --hidden --strip-cwd-prefix'
# Ctrl-R: history rows — press ? to toggle the wrapped preview
export FZF_CTRL_R_OPTS="--preview-window=down:3:hidden:wrap --bind='?:toggle-preview'"
