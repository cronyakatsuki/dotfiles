require("full-border"):setup {
  type = ui.Border.ROUNDED,
}
require("folder-rules"):setup()
require("toggle-pane"):entry("min-preview")
require("git"):setup {
  order = 1500,
}

-- Show symlink target in status bar
Status:children_add(function(self)
  local h = self._current.hovered
  if h and h.link_to then
    return " -> " .. tostring(h.link_to)
  else
    return ""
  end
end, 3300, Status.LEFT)
