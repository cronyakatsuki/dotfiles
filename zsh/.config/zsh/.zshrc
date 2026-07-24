# XDG base directory
# Some applications/plugins rely on this being explicitly set
[ -z "$XDG_CACHE_HOME" ] && export XDG_CACHE_HOME="$HOME/.cache"

# Tmux autostart
if [ -x "$(command -v tmux)" ] && [ -n "${DISPLAY}" ] && [ -z "${TMUX}" ]; then
    exec tmux new-session -A -s default >/dev/null 2>&1
fi

# setup fastfetch
fastfetch

# nice prompt
eval "$(starship init zsh)"
# automatic loading of dev environments
eval "$(direnv hook zsh)"
# better cd
eval "$(zoxide init zsh)"
# history sync and search
eval "$(atuin init zsh)"

# Custom completion directory (must be before compinit)
fpath+=("$HOME/.config/zsh/completions")

# Created by Zap installer
[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ] && source "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"

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
plug "atoftegaard-git/zsh-omz-autocomplete"

export KEYTIMEOUT=15

# Substring search settings
export HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND="bg=blue,fg=black,bold"
export HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='bg=red,fg=black,bold'
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

# History settings
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY          # Share history across sessions
setopt HIST_IGNORE_DUPS       # Don't record duplicate entries
setopt HIST_IGNORE_SPACE      # Don't record commands starting with space
setopt HIST_REDUCE_BLANKS     # Trim whitespace
export HISTTIMEFORMAT="[%F %T]"

HISTFILE="$HOME"/.local/state/zsh/history

# Load home manager variables
source $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh

export SECOND_BRAIN="/home/crony/Documents/sb"

export PI_CODING_AGENT_DIR="$HOME/.local/share/pi/agent"
export NPM_CONFIG_CACHE="$HOME/.cache/npm"
export CUDA_CACHE_PATH="$HOME/.cache/NVIDIA/ComputeCache"
export GOMODCACHE="$HOME/.cache/go/mod"
export GOPATH="$HOME/.local/share/go"
export GNUPGHOME="$HOME/.local/share/gnupg"
export RUSTUP_HOME="$HOME/.local/share/rustup"
export CARGO_HOME="$HOME/.local/share/cargo"
export ATUIN_DATA_DIR="$HOME/.local/share/atuin"

# Sudo askpass helper — graphical password prompt
[ -z "$SUDO_ASKPASS" ] && export SUDO_ASKPASS="/usr/bin/ksshaskpass"
export PATH="$HOME/.local/share/npm-global/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$CARGO_HOME/bin:$PATH"

# ---- Safe Edit (backup + git integration) ----
# Provides auto-backup, rotation (max 5), and git commit for config changes.
# Usage: safe-edit <file>  — opens \$EDITOR with safety net
#        safe-edit backup <file>  — create timestamped backup
#        safe-edit list <file>    — list backups
#        safe-edit restore <file> [n]  — restore from backup
#        safe-edit status <file>  — show VCS/backup status
# Alias: se  → safe-edit
if [ -x "$HOME/.local/bin/safe-edit" ]; then
  alias se='safe-edit'
  # Wrap common operations to go through safe-edit
  # Use: se-conf <file>  — edit a config file with safety
  alias se-conf='safe-edit'
fi

# Yazi function
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	command rm -f -- "$tmp"
}
