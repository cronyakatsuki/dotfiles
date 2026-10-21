# 45-command-not-found.zsh — Command not found handler via apt-file
# Ported from pkgfile (CachyOS/Arch) to apt-file (PikaOS/Debian) 2026-10-21.
# Setup: pikman install apt-file && sudo apt-file update  (refresh db after apt updates)
# Falls back to the plain zsh error if apt-file isn't installed.

if (( $+commands[apt-file] )); then
  command_not_found_handler() {
    local cmd="$1"
    local pkgs
    pkgs=(${(f)"$(apt-file search --package-only -- "$cmd" 2>/dev/null | sort -u)"})

    if [[ -n "$pkgs" ]]; then
      printf '\n  ⚡ %s \033[1;37mnot found\033[0m, but available in:\n\n' "$cmd"
      local pkg
      for pkg in $pkgs; do
        printf '    \033[1;34m\033[0m  \033[0;37m%s\033[0m\n' "$pkg"
      done
      printf '\n    \033[1;33m  Install:\033[0m  pikman install %s\n\n' "${pkgs[(r)$cmd]:-${(j: :)pkgs}}"
    else
      printf 'zsh: command not found: %s\n' "$cmd"
    fi 1>&2

    return 127
  }
fi
