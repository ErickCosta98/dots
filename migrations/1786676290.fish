#!/usr/bin/env fish
# The lock screen's media card only showed title/artist/album and
# prev/play/next — no way to see or scrub playback position, no source app,
# and no album art, unlike the bar's media popup. LockView.qml now mirrors
# that popup: artwork thumbnail, source icon+name, an interactive PanelSlider
# seek bar (polled position/length like the bar widget, paused while
# dragging), and the m:ss / m:ss time readout.

set -l DOTS_DIR $HOME/Work/dots

cp -r $DOTS_DIR/omarchy/omarchy/plugins/erick.lock $HOME/.config/omarchy/plugins/

if command -q omarchy
    omarchy restart shell
end

