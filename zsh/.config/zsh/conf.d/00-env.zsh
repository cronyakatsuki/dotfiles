# 00-env.zsh — Environment variables, XDG base dirs, PATH
# This is sourced first — everything else depends on these paths.

# ---- XDG Base Directories ----
: "${XDG_CACHE_HOME:=$HOME/.cache}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"
: "${XDG_CONFIG_HOME:=$HOME/.config}"
export XDG_CACHE_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CONFIG_HOME

# ---- Zsh History (HISTFILE re-set after plugins in 15-history.zsh) ----
export HISTSIZE=50000
export SAVEHIST=50000
export HISTTIMEFORMAT="[%F %T]"

# ---- Home-manager session vars (Nix) ----
[[ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]] &&
  source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"

# ---- Application-specific data/cache dirs ----
export SECOND_BRAIN="$HOME/Documents/sb"
export NPM_CONFIG_CACHE="${XDG_CACHE_HOME}/npm"
export CUDA_CACHE_PATH="${XDG_CACHE_HOME}/NVIDIA/ComputeCache"
export GOMODCACHE="${XDG_CACHE_HOME}/go/mod"
export GOPATH="${XDG_DATA_HOME}/go"
export GNUPGHOME="${XDG_DATA_HOME}/gnupg"
export RUSTUP_HOME="${XDG_DATA_HOME}/rustup"
export CARGO_HOME="${XDG_DATA_HOME}/cargo"
export ATUIN_DATA_DIR="${XDG_DATA_HOME}/atuin"

# ---- Sudo askpass helper (graphical password prompt) ----
: "${SUDO_ASKPASS:=/usr/bin/ksshaskpass}"
export SUDO_ASKPASS

# ---- PATH — use zsh array for clean deduplication ----
typeset -U path
path=(
  "${XDG_DATA_HOME}/npm-global/bin"
  "${HOME}/.local/bin"
  "${CARGO_HOME}/bin"
  "${GOPATH}/bin"
  $path
)
# ---- API Keys (gitignored secrets) ----
if [ -f "$HOME/.config/secrets.env" ]; then
  source "$HOME/.config/secrets.env"
fi

export PATH
