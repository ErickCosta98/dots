#!/usr/bin/env fish
# Re-deploy erick.lan-mouse after fixing the Add-machine TextField binding
# (onTextEdited wrote to a non-existent root property, so typing into the
# fields silently did nothing) and correcting the default port shown in
# the UI/docs (4242, not Input Leap's 24800). Same files as the
# 1786745289 migration; this one exists because that one already ran on
# other machines before these fixes landed.

set -l DOTS_DIR $HOME/Work/dots

mkdir -p $HOME/.config/omarchy/plugins
cp -r $DOTS_DIR/omarchy/omarchy/plugins/erick.lan-mouse $HOME/.config/omarchy/plugins/

cp $DOTS_DIR/omarchy/omarchy/shell.json $HOME/.config/omarchy/shell.json

if command -q omarchy
    omarchy restart shell
end
