#!/usr/bin/env fish
# Wire up custom waybar weather module (Open-Meteo + IP/city override) instead
# of Omarchy's stock IP-geolocated weather.sh.

set -l DOTS_DIR $HOME/Work/dots
set -l GREEN (set_color green)
set -l RESET (set_color normal)

echo $GREEN"[migration]"$RESET" Copying waybar weather files..."
cp $DOTS_DIR/waybar/waybar/weather.sh $HOME/.config/waybar/weather.sh
cp $DOTS_DIR/waybar/waybar/weather-location.conf $HOME/.config/waybar/weather-location.conf
cp $DOTS_DIR/waybar/waybar/config.jsonc $HOME/.config/waybar/config.jsonc
chmod +x $HOME/.config/waybar/weather.sh

if command -q omarchy
    omarchy restart waybar
end
