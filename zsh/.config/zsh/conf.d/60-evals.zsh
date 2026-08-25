# 60-evals.zsh — Hook evaluations (direnv, zoxide, atuin)

# Automatic loading of dev environments
eval "$(direnv hook zsh)"

# Better cd — jump to frequently used directories
eval "$(zoxide init zsh)"

# History sync and search across sessions
eval "$(atuin init zsh)"
