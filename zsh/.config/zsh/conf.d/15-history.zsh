# 15-history.zsh — History file location (set after plugins to avoid override)
# Plugins like Zap/completions run compinit which may reset HISTFILE,
# so this must come after 10-plugins.zsh.

export HISTFILE="${XDG_STATE_HOME}/zsh/history"

# ensure history dir exists on fresh installs (only touches disk when missing)
[[ -d "${XDG_STATE_HOME}/zsh" ]] || mkdir -p -- "${XDG_STATE_HOME}/zsh"
