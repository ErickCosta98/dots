#!/usr/bin/env fish
# Input Leap bar widget (erick.input-leap): controls/shows the input-leapc
# (client) or input-leaps (server) process from the Quickshell bar, with
# state detection via the managed Process plus a pgrep poll for instances
# started outside Quickshell. Requires input-leap-bin (see packages.txt).

set -l DOTS_DIR $HOME/Work/dots

mkdir -p $HOME/.config/omarchy/plugins
cp -r $DOTS_DIR/omarchy/omarchy/plugins/erick.input-leap $HOME/.config/omarchy/plugins/

cp $DOTS_DIR/omarchy/omarchy/shell.json $HOME/.config/omarchy/shell.json

if command -q omarchy
    omarchy restart shell
end
