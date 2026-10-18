# paneru-preview

A Darwin menu-bar-less panel for the running paneru strip. It is a paneru client. It does not capture the desktop as a second status bar.

One block per tiled column. The block is a top slice of that window, drawn as 9×6 pt minimap cells. Unfocused columns are dimmed. A white stroke marks the part of the strip that lies on the current display. A click runs `paneru send-cmd window focus <column>`.

Build:

```
nix build .#paneru-preview
```

The output is an app bundle. The executable is `Contents/MacOS/paneru-preview`. Screen Recording permission is required before the cells show window content.
