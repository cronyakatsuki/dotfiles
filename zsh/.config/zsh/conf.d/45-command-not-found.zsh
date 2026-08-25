# 45-command-not-found.zsh — Command not found handler via pkgfile
# Uses pkgfile to search CachyOS repos for the missing command.
# Run: pkgfile -u  (as root) to update the database.

command_not_found_handler() {
  local cmd="$1"
  local pkgs
  pkgs=(${(f)"$(pkgfile -b -v -- "$cmd" 2>/dev/null)"})

  if [[ -n "$pkgs" ]]; then
    printf '\n  ⚡ %s \033[1;37mnot found\033[0m, but available in:\n\n' "$cmd"
    for pkg in $pkgs[@]; do
      local repo_pkg="${pkg% *}"
      local version="${pkg##* }"
      printf '    \033[1;34m\033[0m  %-40s \033[0;37m%s\033[0m\n' "$repo_pkg" "$version"
    done
    printf '\n    \033[1;33m  Install:\033[0m  sudo pacman -S %s\n\n' "$cmd"
  else
    printf 'zsh: command not found: %s\n' "$cmd"
  fi 1>&2

  return 127
}
