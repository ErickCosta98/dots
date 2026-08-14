#!/usr/bin/env fish
# Re-deploy erick.lan-mouse with the left/right/top/bottom position picker
# for paired machines (add-client has no --position flag, so the plugin
# now follows up with set-position after adding when a non-default
# position is chosen). Same files as the 1786745956 migration; this one
# exists because that one already ran on other machines before this
# feature landed.

set -l DOTS_DIR $HOME/Work/dots

mkdir -p $HOME/.config/omarchy/plugins
cp -r $DOTS_DIR/omarchy/omarchy/plugins/erick.lan-mouse $HOME/.config/omarchy/plugins/

cp $DOTS_DIR/omarchy/omarchy/shell.json $HOME/.config/omarchy/shell.json

if command -q omarchy
    omarchy restart shell
end
