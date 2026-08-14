#!/usr/bin/env fish
# Re-deploy erick.input-leap after forcing --use-x11 (this Hyprland
# session's xdg-desktop-portal has no org.freedesktop.portal.RemoteDesktop
# implementation, so Input Leap's default backend failed with "No such
# interface") and passing --name in client mode too. Same files as the
# previous erick.input-leap migrations; this one exists because those
# already ran on other machines before this fix landed.

set -l DOTS_DIR $HOME/Work/dots

mkdir -p $HOME/.config/omarchy/plugins
cp -r $DOTS_DIR/omarchy/omarchy/plugins/erick.input-leap $HOME/.config/omarchy/plugins/

cp $DOTS_DIR/omarchy/omarchy/shell.json $HOME/.config/omarchy/shell.json

if command -q omarchy
    omarchy restart shell
end
