#!/usr/bin/env fish
# local_ip.sh tenía la interfaz hardcodeada a wlan0, así que en máquinas
# conectadas por LAN (eth0/enp...) el módulo de waybar siempre mostraba
# "No IP". Ahora detecta la interfaz activa automáticamente vía la ruta
# por defecto, sirve igual para wifi que para lan.

set -l DOTS_DIR $HOME/Work/dots

cp $DOTS_DIR/waybar/waybar/local_ip.sh $HOME/.config/waybar/local_ip.sh
chmod +x $HOME/.config/waybar/local_ip.sh

if command -q omarchy
    omarchy restart waybar
end
