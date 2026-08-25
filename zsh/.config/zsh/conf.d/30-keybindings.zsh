# 30-keybindings.zsh — Keybindings

# ---- History substring search appearance ----
export HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND="bg=blue,fg=black,bold"
export HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='bg=red,fg=black,bold'

# ---- Vim-mode history search (j/k in normal mode) ----
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down
