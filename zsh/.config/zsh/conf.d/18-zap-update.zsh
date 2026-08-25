# 18-zap-update.zsh — Silent weekly plugin update check
# Runs 'zap update plugins' in the background at most once per 7 days.

ZAP_UPDATE_MARKER="${XDG_CACHE_HOME}/zap/.last-update"

if [[ ! -f "$ZAP_UPDATE_MARKER" ]]; then
    # First run — update now (in background)
    mkdir -p "${XDG_CACHE_HOME}/zap"
    zap update plugins &> /dev/null &
    touch "$ZAP_UPDATE_MARKER"
elif [[ $(find "$ZAP_UPDATE_MARKER" -mtime +7 2>/dev/null) ]]; then
    # Older than 7 days — update in background
    zap update plugins &> /dev/null &
    touch "$ZAP_UPDATE_MARKER"
fi
