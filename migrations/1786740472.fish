#!/usr/bin/env fish
# Re-deploy erick.input-leap after disabling Input Leap's own TLS
# (--disable-crypto on both client and server invocations) — connecting
# with the default TLS failed with "ssl certificate doesn't exist" since
# nothing here generates that certificate. Same files as the previous
# erick.input-leap migrations; this one exists because those already ran
# on other machines before this fix landed.

set -l DOTS_DIR $HOME/Work/dots

mkdir -p $HOME/.config/omarchy/plugins
cp -r $DOTS_DIR/omarchy/omarchy/plugins/erick.input-leap $HOME/.config/omarchy/plugins/

cp $DOTS_DIR/omarchy/omarchy/shell.json $HOME/.config/omarchy/shell.json

if command -q omarchy
    omarchy restart shell
end
