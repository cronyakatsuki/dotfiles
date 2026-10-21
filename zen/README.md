# zen stow package

Flatpak `app.zen_browser.zen` profile chrome css. Files are **copied** into
`~/.var/app/app.zen_browser.zen/.zen/main/chrome/` — stow symlinks do NOT work
here (flatpak gecko won't load symlinked chrome files even with a
`filesystem=~/dotfiles/zen:ro` override; verified 2026-10-21).

## Sync after editing

```bash
just sync-zen-chrome    # from ~/dotfiles
```

Then fully restart zen.

`zen-themes.css` / `zen-themes/` are app-generated (ZenMods) — never edit or sync.
