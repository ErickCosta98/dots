#!/usr/bin/env fish
# Bump waybar height (26px -> 36px) so 25-26px custom icons (ghostty/ssh
# terminal, ip-local expand) actually fit instead of clipping/looking cramped.

set -l DOTS_DIR $HOME/Work/dots

cp $DOTS_DIR/waybar/waybar/config.jsonc $HOME/.config/waybar/config.jsonc

if command -q omarchy
    omarchy restart waybar
end
