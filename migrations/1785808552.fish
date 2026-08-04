#!/usr/bin/env fish
# Install ttf-firacode-nerd (waybar's font-family) — Omarchy's base install
# only provides ttf-jetbrains-mono-nerd, so without this package waybar falls
# back to a font with different glyph metrics, clipping icons.

sudo pacman -S --needed --noconfirm ttf-firacode-nerd

if command -q omarchy
    omarchy restart waybar
end
