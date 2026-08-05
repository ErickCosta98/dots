#!/bin/bash
# Obtiene la IP local de la interfaz activa (detectada automáticamente,
# funciona igual con wifi que con lan)
INTERFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')
IP=$(ip addr show "$INTERFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [ -n "$IP" ]; then
    echo "{\"text\": \"$IP\", \"tooltip\": \"IP Local ($INTERFACE)\", \"class\": \"ip-local\"}"
else
    echo "{\"text\": \"No IP\", \"tooltip\": \"No se detectó IP en ninguna interfaz activa\", \"class\": \"ip-error\"}"
fi
