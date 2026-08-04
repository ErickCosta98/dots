#!/usr/bin/env fish
# Regenerate monitors.conf from this machine's actually detected hardware,
# instead of whatever hardcoded layout got copied from another laptop.

set -l DOTS_DIR $HOME/Work/dots

if command -q hyprctl
    fish $DOTS_DIR/generate-monitors.fish
else
    echo "hyprctl not available — run 'fish $DOTS_DIR/generate-monitors.fish' manually once inside Hyprland."
end
