#!/usr/bin/env fish
# Restore original ip-local/ssh icon font-sizes (25px/26px) now that
# ttf-firacode-nerd is installed and the clipping is resolved.

set -l DOTS_DIR $HOME/Work/dots

cp $DOTS_DIR/waybar/waybar/style.css $HOME/.config/waybar/style.css

if command -q omarchy
    omarchy restart waybar
end
