#!/usr/bin/env fish
# input.lua was lost from ~/.config/hypr on a recent omarchy update, which
# reset the file to Omarchy's commented-out template and dropped the
# us,es layout + Left Alt/Right Alt toggle. Re-adds it here so it survives
# future updates.

set -l DOTS_DIR $HOME/Work/dots

cp $DOTS_DIR/hypr/hypr/input.lua $HOME/.config/hypr/input.lua

if command -q hyprctl
    hyprctl reload
end
