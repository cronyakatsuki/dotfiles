# fonts stow package

User-level fonts, symlinked to `~/.local/share/fonts/`.

## Contents
- `monaspace/` — Monaspace Neon **Frozen** v1.400, core 4 styles (Regular/Bold/Italic/BoldItalic).
  Source: https://github.com/githubnext/monaspace/releases (SIL OFL). Downloaded from
  `monaspace-frozen-v1.400.zip` → `Frozen Fonts/Monaspace Neon/` (only non-Wide core styles vendored).
- `Symbols Nerd Font Mono` comes from the **system package** `fonts-nerd-symbols` (pikman), NOT from
  this repo — reinstall it after a fresh distro install: `pikman install fonts-nerd-symbols`.

## Update vendored fonts
Download the new `monaspace-frozen-vX.Y.zip`, replace the TTFs here, `fc-cache -f ~/.local/share/fonts`.
