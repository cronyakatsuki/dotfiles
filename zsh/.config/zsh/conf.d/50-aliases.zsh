# 50-aliases.zsh — Aliases

# ---- Better eza (extends what the exa plugin provides) ----
alias lt='eza --tree --level=2 --icons=auto'
alias l='eza -lbF --icons=auto'

# ---- Safe Edit ----
# Provides auto-backup, rotation (max 5), and git commit for config changes.
if [[ -x "$HOME/.local/bin/safe-edit" ]]; then
  alias se='safe-edit'
  alias se-conf='safe-edit'
fi
