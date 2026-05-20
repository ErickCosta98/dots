#!/usr/bin/env bash
# weather.sh — Clima para hyprlock usando Open-Meteo
# Modos: (sin args) → ícono+temp | desc → descripción
# Ciudad: San Cristóbal de las Casas, Chiapas, México

LAT="16.7370"
LON="-92.6376"
CACHE_FILE="/tmp/hyprlock-weather.cache"
CACHE_MAX_AGE=300  # 5 minutos

MODE="${1:-temp}"

get_icon() {
  case $1 in
    0)        echo "" ;;
    1)        echo "" ;;
    2)        echo "" ;;
    3)        echo "" ;;
    45|48)    echo "" ;;
    51|53|55) echo "" ;;
    61|63|65) echo "" ;;
    71|73|75) echo "" ;;
    80|81|82) echo "" ;;
    95)       echo "" ;;
    96|99)    echo "" ;;
    *)        echo "" ;;
  esac
}

get_description() {
  case $1 in
    0)  echo "Despejado" ;;
    1)  echo "Principalmente despejado" ;;
    2)  echo "Parcialmente nublado" ;;
    3)  echo "Nublado" ;;
    45) echo "Niebla" ;;
    48) echo "Niebla con escarcha" ;;
    51) echo "Llovizna ligera" ;;
    53) echo "Llovizna moderada" ;;
    55) echo "Llovizna densa" ;;
    61) echo "Lluvia ligera" ;;
    63) echo "Lluvia moderada" ;;
    65) echo "Lluvia intensa" ;;
    71) echo "Nevada ligera" ;;
    73) echo "Nevada moderada" ;;
    75) echo "Nevada intensa" ;;
    80) echo "Chubascos ligeros" ;;
    81) echo "Chubascos moderados" ;;
    82) echo "Chubascos violentos" ;;
    95) echo "Tormenta" ;;
    96) echo "Tormenta con granizo" ;;
    99) echo "Tormenta con granizo fuerte" ;;
    *)  echo "Desconocido" ;;
  esac
}

output_mode() {
  local icon="$1" temp="$2" desc="$3"
  case "$MODE" in
    desc) echo "$desc" ;;
    *)    echo "${icon} ${temp}°C" ;;
  esac
}

# Usar caché si es reciente (formato: ICON|TEMP|DESC)
if [ -f "$CACHE_FILE" ]; then
  AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
  if [ "$AGE" -lt "$CACHE_MAX_AGE" ]; then
    IFS='|' read -r C_ICON C_TEMP C_DESC < "$CACHE_FILE"
    output_mode "$C_ICON" "$C_TEMP" "$C_DESC"
    exit 0
  fi
fi

DATA=$(curl -sf --max-time 10 \
  "https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,weather_code&timezone=America%2FMexico_City")

if [ $? -ne 0 ] || [ -z "$DATA" ]; then
  if [ -f "$CACHE_FILE" ]; then
    IFS='|' read -r C_ICON C_TEMP C_DESC < "$CACHE_FILE"
    output_mode "$C_ICON" "$C_TEMP" "$C_DESC"
  else
    [ "$MODE" = "desc" ] && echo "Sin conexión" || echo "  --°C"
  fi
  exit 0
fi

TEMP=$(echo "$DATA" | jq -r '.current.temperature_2m // empty')
CODE=$(echo "$DATA" | jq -r '.current.weather_code // 0')

if [ -z "$TEMP" ]; then
  [ "$MODE" = "desc" ] && echo "Sin datos" || echo "  --°C"
  exit 0
fi

ICON=$(get_icon "$CODE")
DESC=$(get_description "$CODE")
TEMP_INT=$(printf "%.0f" "$TEMP")

echo "${ICON}|${TEMP_INT}|${DESC}" > "$CACHE_FILE"
output_mode "$ICON" "$TEMP_INT" "$DESC"
