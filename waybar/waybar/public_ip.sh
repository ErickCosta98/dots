#!/bin/bash
# Obtiene la IP pública usando curl y un servicio externo
IP=$(curl -s https://api.ipify.org)
if [ -n "$IP" ]; then
    echo "{\"text\": \"$IP\", \"tooltip\": \"IP Pública\", \"class\": \"ip-public\"}"
else
    echo "{\"text\": \"No conexión\", \"tooltip\": \"No se pudo obtener la IP\", \"class\": \"ip-error\"}"
fi