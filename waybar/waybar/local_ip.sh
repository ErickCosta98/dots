#!/bin/bash
# Obtiene la IP local de la interfaz activa (ajusta wlan0 según tu interfaz)
INTERFACE="wlan0"  # Cambia a eth0, enp0s3, etc., según tu sistema
IP=$(ip addr show $INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "No IP")
if [ "$IP" != "No IP" ]; then
    echo "{\"text\": \"$IP\", \"tooltip\": \"IP Local ($INTERFACE)\", \"class\": \"ip-local\"}"
else
    echo "{\"text\": \"No IP\", \"tooltip\": \"No se detectó IP en $INTERFACE\", \"class\": \"ip-error\"}"
fi