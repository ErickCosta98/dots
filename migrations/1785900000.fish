#!/usr/bin/env fish
# Fix hypridle screensaver timeout: it was set to 252s (higher than the
# 152s lock timeout), so hyprlock always fired first and the screensaver
# listener's "pidof hyprlock" check silently skipped it. Restore 150s so
# the screensaver runs before the lock (150s < 152s), matching upstream.

set -l DOTS_DIR $HOME/Work/dots

cp $DOTS_DIR/hypr/hypr/hypridle.conf $HOME/.config/hypr/hypridle.conf

if command -q omarchy
    omarchy restart hypridle
end
