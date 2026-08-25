# 50-aliases.zsh — Aliases

# ---- Better eza (extends what the exa plugin provides) ----
alias lt='eza --tree --level=2 --icons=auto'
alias l='eza -lbF --icons=auto'

# ---- fd defaults ----
# --hidden: include dotfiles, --strip-cwd-prefix: drop the ./ prefix on results
alias fd='fd --hidden --strip-cwd-prefix'
alias fdf='fd --type f --hidden --strip-cwd-prefix'  # files only
alias fdd='fd --type d --hidden --strip-cwd-prefix'  # dirs only

# ---- duf / dust (readable replacements for df / du) ----
alias df='duf'
alias du='dust -b'  # dust with size bars

# ---- Safe Edit ----
# Provides auto-backup, rotation (max 5), and git commit for config changes.
if [[ -x "$HOME/.local/bin/safe-edit" ]]; then
  alias se='safe-edit'
  alias se-conf='safe-edit'
fi
