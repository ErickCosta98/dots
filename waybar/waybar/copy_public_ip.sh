#!/bin/bash

CACHE="$HOME/.config/waybar/cache/public_ip.txt"

if [ -f "$CACHE" ]; then
    ip=$(cat "$CACHE")
    echo "$ip" | wl-copy
    notify-send "Public IP copied" "$ip"
else
    notify-send "Public IP" "Cache not found"
fi
