#!/usr/bin/env fish
# Omarchy dropped Waybar in favor of its own Quickshell bar
# (~/.config/omarchy/shell.json + plugins). Waybar's config.jsonc/style.css
# no longer apply — there's no Waybar process anymore. This migration ports
# the custom extras (local/public IP widgets, Ghostty/Alacritty-SSH
# launchers) into the new bar as command/qml modules, restoring the
# functionality that got dropped when omarchy replaced the bar engine.

set -l DOTS_DIR $HOME/Work/dots

mkdir -p $HOME/.config/omarchy/bar/scripts
mkdir -p $HOME/.config/omarchy/bar/modules

cp $DOTS_DIR/omarchy/omarchy/bar/scripts/local-ip.sh $HOME/.config/omarchy/bar/scripts/local-ip.sh
cp $DOTS_DIR/omarchy/omarchy/bar/scripts/public-ip.sh $HOME/.config/omarchy/bar/scripts/public-ip.sh
chmod +x $HOME/.config/omarchy/bar/scripts/local-ip.sh $HOME/.config/omarchy/bar/scripts/public-ip.sh

cp $DOTS_DIR/omarchy/omarchy/bar/modules/ip-local.qml $HOME/.config/omarchy/bar/modules/ip-local.qml
cp $DOTS_DIR/omarchy/omarchy/bar/modules/ip-public.qml $HOME/.config/omarchy/bar/modules/ip-public.qml

cp $DOTS_DIR/omarchy/omarchy/shell.json $HOME/.config/omarchy/shell.json

if command -q omarchy
    omarchy restart shell
end
