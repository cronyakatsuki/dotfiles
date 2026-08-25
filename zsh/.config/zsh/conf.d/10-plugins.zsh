# 10-plugins.zsh — Plugin manager & plugin declarations

# Custom completion directory (must be before compinit)
fpath+=("${ZDOTDIR}/completions")

# Zap plugin manager
zap_file="${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"
[[ -f "$zap_file" ]] && source "$zap_file"

plug "cronyakatsuki/supercharge"
plug "zap-zsh/completions"
plug "zap-zsh/vim"
plug "zsh-users/zsh-autosuggestions"
plug "zsh-users/zsh-completions"
plug "chivalryq/git-alias"
plug "zap-zsh/fzf"
plug "zdharma-continuum/fast-syntax-highlighting"
plug "zsh-users/zsh-history-substring-search"
plug "MichaelAquilina/zsh-you-should-use"
plug "zap-zsh/exa"
plug "hlissner/zsh-autopair"
plug "MichaelAquilina/zsh-auto-notify"
