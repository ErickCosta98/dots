#!/usr/bin/env fish
# The ip-local/ip-public bar widgets each had a 1-hour Timer with
# triggeredOnStart. If the network wasn't up yet at that first tick (e.g.
# right after login, before Wi-Fi/DHCP finished), the script's failure
# message ("No IP"/"No conexión") stuck for a full hour with no way to
# retry. Left-click now re-runs the check on demand and copies the freshly
# fetched IP (not the stale one) once the process finishes; right-click
# still copies the currently displayed value without refreshing.

set -l DOTS_DIR $HOME/Work/dots

cp $DOTS_DIR/omarchy/omarchy/bar/modules/ip-local.qml $HOME/.config/omarchy/bar/modules/
cp $DOTS_DIR/omarchy/omarchy/bar/modules/ip-public.qml $HOME/.config/omarchy/bar/modules/
cp $DOTS_DIR/omarchy/omarchy/bar/scripts/local-ip.sh $HOME/.config/omarchy/bar/scripts/
cp $DOTS_DIR/omarchy/omarchy/bar/scripts/public-ip.sh $HOME/.config/omarchy/bar/scripts/

if command -q omarchy
    omarchy restart shell
end

