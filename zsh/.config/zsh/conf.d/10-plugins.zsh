# 10-plugins.zsh — Plugin manager & plugin declarations

# Custom completion directory (must be before compinit)
fpath+=("${ZDOTDIR}/completions")

# Zap plugin manager (bootstrapped via `just bootstrap`; warn if missing)
zap_file="${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"
if [[ -f "$zap_file" ]]; then source "$zap_file"
else print -P " %F{yellow}zap missing — run: just bootstrap%f" >&2; fi

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
# plug "MichaelAquilina/zsh-auto-notify"  # removed 2026-10-15: too noisy, fires even when the terminal is focused (plugin has no focus detection)
