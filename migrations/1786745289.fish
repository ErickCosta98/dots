#!/usr/bin/env fish
# Replace erick.input-leap with erick.lan-mouse: Input Leap's --use-x11
# fallback can't inject input into native Wayland apps on this Hyprland
# session, and the proper EI/portal backend isn't available since
# xdg-desktop-portal-hyprland doesn't implement InputCapture/RemoteDesktop.
# lan-mouse (Arch's official extra/lan-mouse) works here via wlr-layer-shell
# capture + wlroots emulation. Other machines that ran the old
# erick.input-leap migrations need their deployed copy cleaned up too.

set -l DOTS_DIR $HOME/Work/dots

rm -rf $HOME/.config/omarchy/plugins/erick.input-leap

mkdir -p $HOME/.config/omarchy/plugins
cp -r $DOTS_DIR/omarchy/omarchy/plugins/erick.lan-mouse $HOME/.config/omarchy/plugins/

cp $DOTS_DIR/omarchy/omarchy/shell.json $HOME/.config/omarchy/shell.json

if command -q omarchy
    omarchy restart shell
end
