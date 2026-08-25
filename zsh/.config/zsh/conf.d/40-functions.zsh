# 40-functions.zsh — Custom shell functions

# ---- Quick directory: mkdir + cd in one ----
take() {
    mkdir -p "$1" && cd "$1"
}

# ---- Yazi: cd on quit ----
# Opens yazi file manager; if the directory changes, cd into it.
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    command yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [[ "$cwd" != "$PWD" && -d "$cwd" ]] && builtin cd -- "$cwd"
    command rm -f -- "$tmp"
}
