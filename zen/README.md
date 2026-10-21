# zen stow package

Chrome css for Zen browser. Package stows to `~/.config/zen/main/chrome/`
(native-install layout) so a non-flatpak zen can `stow zen` directly.

## Current flatpak install

Zen is a flatpak (`app.zen_browser.zen`), profile at
`~/.var/app/app.zen_browser.zen/.zen/main/`. Flatpak gecko will NOT load
symlinked chrome files, so the profile gets **copies**, pushed from this repo:

```bash
just sync-zen-chrome    # from ~/dotfiles, then fully restart zen
```

If zen ever moves to a native package: `stow zen` (from ~/dotfiles) and skip the
sync step — the symlink target already matches the native layout.

`zen-themes.css` / `zen-themes/` are app-generated (ZenMods) — never edit or sync.
