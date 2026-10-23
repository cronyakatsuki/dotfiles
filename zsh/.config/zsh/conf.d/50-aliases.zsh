# 50-aliases.zsh — Aliases

# ---- Better eza (extends what the exa plugin provides) ----
alias lt='eza --tree --level=2 --icons=auto'
alias l='eza -lbF --icons=auto'

# ---- fd defaults ----
# --hidden: include dotfiles
# NOTE: no --strip-cwd-prefix here — fd 10 makes it conflict with an explicit
# path argument (cd ~/dotfiles && fd foo /etc would error). Default no-path
# searches show the ./ prefix; drop it manually if it bothers you.
alias fd='fd --hidden'
alias fdf='fd --type f --hidden'  # files only
alias fdd='fd --type d --hidden'  # dirs only

# ---- duf / dust (readable replacements for df / du) ----
alias df='duf'
alias du='dust -b'  # dust with size bars

# ---- Safe Edit ----
# Provides auto-backup, rotation (max 5), and git commit for config changes.
if [[ -x "$HOME/.local/bin/safe-edit" ]]; then
  alias se='safe-edit'
  alias se-conf='safe-edit'
fi
