#!/usr/bin/env fish
# natural scroll on touchpad + drop orphaned hyprland.conf/input.conf
#
# Omarchy's Lua migration made ~/.config/hypr/hyprland.lua the real entry
# point (it requires hypr.input, i.e. input.lua). The old hyprland.conf and
# input.conf are no longer sourced by anything, but input.conf's leftover
# natural_scroll = true made it look like it was still in effect. Since it
# wasn't, the touchpad was actually running on Omarchy's default
# (natural_scroll = false), which reads as "scroll got inverted".

set -l DOTS_DIR $HOME/Work/dots

cp $DOTS_DIR/hypr/hypr/input.lua $HOME/.config/hypr/input.lua
rm -f $HOME/.config/hypr/input.conf $HOME/.config/hypr/hyprland.conf

if command -q hyprctl
    hyprctl reload
end
