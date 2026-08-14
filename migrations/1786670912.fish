#!/usr/bin/env fish
# Custom Quickshell lock screen (erick.lock, ported from the old hyprlock.conf
# design: greeting/hostname, clock+uptime, weather, battery, MPRIS media with
# playback controls) and a media bar widget (erick.media, cloned from
# omarchy.media so a left-click opens the info/controls popup instead of
# toggling playback). Both clones override the first-party plugins they came
# from, so shell.json's disabledPlugins/cloneSourceRestores must ship together
# with them or the shell falls back to the stock lock/media plugins.

set -l DOTS_DIR $HOME/Work/dots

mkdir -p $HOME/.config/omarchy/plugins
cp -r $DOTS_DIR/omarchy/omarchy/plugins/erick.lock $HOME/.config/omarchy/plugins/
cp -r $DOTS_DIR/omarchy/omarchy/plugins/erick.media $HOME/.config/omarchy/plugins/

cp $DOTS_DIR/omarchy/omarchy/shell.json $HOME/.config/omarchy/shell.json

if command -q omarchy
    omarchy restart shell
end
