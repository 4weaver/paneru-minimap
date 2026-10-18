# paneru-minimap

A Darwin menu-bar-less panel for the running paneru strip. It is a paneru client. It does not capture the desktop as a second status bar.

One block per tiled column. The block is a top slice of that window, drawn as 9×6 pt minimap cells. Unfocused columns are dimmed. A white stroke marks the part of the strip that lies on the current display. A click runs `paneru send-cmd window focus <column>`.

Build:

```
nix build .#paneru-minimap
```

The output is an app bundle. The executable is `Contents/MacOS/paneru-minimap`. Screen Recording permission is required before the cells show window content.

Settings are `config.json` in the bundle, then `~/.config/paneru-minimap/config.json` if that file exists. Keys: `barHeight`, `screenInset`, `cellWidth`, `cellHeight`, `unfocusedShade`, `unfocusedWash`, `filter` (`none` or `minimap`), `shape` (`square` or `dot`, used by `minimap`).

