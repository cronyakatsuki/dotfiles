# 05-tmux.zsh — Tmux autostart
# If tmux is available and we're in a graphical session, start/reuse a session.
# Set NO_TMUX_AUTOSTART=1 in env to disable.

if [[ -x "$(command -v tmux)" && -n "${DISPLAY}" && -z "${TMUX}" && -z "${NO_TMUX_AUTOSTART}" ]]; then
    exec tmux new-session -A -s default >/dev/null 2>&1
fi
