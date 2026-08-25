# 55-fzf-theme.zsh — Catppuccin Mocha Lavender for fzf + default behavior
# Colors + layout/preview defaults; file/dir sources are fd-backed.
# (zap-zsh/fzf only sources stock bindings, so these vars are free.)
export FZF_DEFAULT_OPTS=" \
  --color=bg+:#313244,bg:#1E1E2E,spinner:#B4BEFE,hl:#B4BEFE \
  --color=fg:#CDD6F4,header:#B4BEFE,info:#B4BEFE,pointer:#B4BEFE \
  --color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#B4BEFE,hl+:#B4BEFE \
  --color=selected-bg:#45475A \
  --color=border:#6C7086,label:#CDD6F4 \
  --layout=reverse --height=40% --border --info=inline \
  --preview 'bat -f --line-range=:200 {}'"

# Ctrl-T: files only, dotfiles included, no ./ prefix (global fd ignore applies)
export FZF_CTRL_T_COMMAND='fd --type f --hidden --strip-cwd-prefix'
# Alt-C: directories only
export FZF_ALT_C_COMMAND='fd --type d --hidden --strip-cwd-prefix'
# Ctrl-R: history rows — press ? to toggle the wrapped preview
export FZF_CTRL_R_OPTS="--preview-window=down:3:hidden:wrap --bind='?:toggle-preview'"
