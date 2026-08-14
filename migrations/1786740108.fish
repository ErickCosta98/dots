#!/usr/bin/env fish
# Re-deploy erick.input-leap after fixing the server-mode topology config
# generation, the popup's keyboard focus (PopupCard -> KeyboardPanel), and
# live TextField commit (onEditingFinished -> onTextEdited). Same files as
# the 1786739067 migration; this one exists because that migration already
# ran on other machines before these fixes landed.

set -l DOTS_DIR $HOME/Work/dots

mkdir -p $HOME/.config/omarchy/plugins
cp -r $DOTS_DIR/omarchy/omarchy/plugins/erick.input-leap $HOME/.config/omarchy/plugins/

cp $DOTS_DIR/omarchy/omarchy/shell.json $HOME/.config/omarchy/shell.json

if command -q omarchy
    omarchy restart shell
end
