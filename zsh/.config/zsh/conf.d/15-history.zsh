# 15-history.zsh — History file location (set after plugins to avoid override)
# Plugins like Zap/completions run compinit which may reset HISTFILE,
# so this must come after 10-plugins.zsh.

export HISTFILE="${XDG_STATE_HOME}/zsh/history"
