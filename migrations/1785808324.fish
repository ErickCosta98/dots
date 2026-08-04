#!/usr/bin/env fish
# Normalize oversized custom waybar icon font-sizes (25-26px -> 20px) that
# kept clipping even after the bar height bump.

set -l DOTS_DIR $HOME/Work/dots

cp $DOTS_DIR/waybar/waybar/style.css $HOME/.config/waybar/style.css

if command -q omarchy
    omarchy restart waybar
end
