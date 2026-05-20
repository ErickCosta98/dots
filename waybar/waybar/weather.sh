#!/usr/bin/env bash
# weather.sh - Clima para waybar usando Open-Meteo (mismo proveedor que stormy)
# Ciudad: San Cristóbal de las Casas, Chiapas, México

# Coordenadas de San Cristóbal de las Casas
LAT="16.7370"
LON="-92.6376"

# Iconos Nerd Font (monocromáticos)
get_icon() {
  local code=$1
  case $code in
    0)  echo "" ;;        # Día despejado
    1)  echo "" ;;        # Mayormente despejado
    2)  echo "" ;;        # Parcialmente nublado
    3)  echo "" ;;        # Nublado
    45|48) echo "" ;;     # Niebla
    51|53|55) echo "" ;;  # Llovizna
    61|63|65) echo "" ;;  # Lluvia
    71|73|75) echo "" ;;  # Nieve
    80|81|82) echo "" ;;  # Chubascos
    95) echo "" ;;        # Tormenta
    96|99) echo "" ;;     # Tormenta fuerte / granizo
    *)  echo "" ;;        # Temperatura
  esac
}

# Descripción según WMO codes
get_description() {
  local code=$1
  case $code in
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

# Obtener datos de Open-Meteo
DATA=$(curl -sf --max-time 10 \
  "https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m&wind_speed_unit=kmh&timezone=America%2FMexico_City")

if [ $? -ne 0 ] || [ -z "$DATA" ]; then
  echo '{"text":"  --°C", "tooltip":"Sin datos climáticos", "class":"weather-error"}'
  exit 0
fi

TEMP=$(echo "$DATA" | jq -r '.current.temperature_2m // "N/A"')
HUMIDITY=$(echo "$DATA" | jq -r '.current.relative_humidity_2m // "N/A"')
WIND=$(echo "$DATA" | jq -r '.current.wind_speed_10m // "N/A"')
CODE=$(echo "$DATA" | jq -r '.current.weather_code // 0')

ICON=$(get_icon "$CODE")
DESC=$(get_description "$CODE")

# Temperatura redondeada
TEMP_INT=$(printf "%.0f" "$TEMP" 2>/dev/null || echo "$TEMP")

# Clase según temperatura
if [ "$TEMP_INT" -ge 30 ] 2>/dev/null; then
  TEMP_CLASS="hot"
elif [ "$TEMP_INT" -ge 20 ] 2>/dev/null; then
  TEMP_CLASS="warm"
elif [ "$TEMP_INT" -ge 10 ] 2>/dev/null; then
  TEMP_CLASS="cool"
else
  TEMP_CLASS="cold"
fi

# Clase según condición
case $CODE in
  0) WEATHER_CLASS="clear" ;;
  1|2) WEATHER_CLASS="partly" ;;
  3) WEATHER_CLASS="cloudy" ;;
  45|48) WEATHER_CLASS="fog" ;;
  51|53|55|61|63|65|80|81|82) WEATHER_CLASS="rain" ;;
  71|73|75) WEATHER_CLASS="snow" ;;
  95|96|99) WEATHER_CLASS="storm" ;;
  *) WEATHER_CLASS="default" ;;
esac

TEXT="${ICON} ${TEMP_INT}°C"
TOOLTIP="${ICON}  ${DESC}\n\
  Temperatura: ${TEMP}°C\n\
  Humedad: ${HUMIDITY}%\n\
  Viento: ${WIND} km/h\n\
  San Cristóbal de las Casas"

printf '{"text":"%s", "tooltip":"%s", "class":"weather %s %s"}' \
"$TEXT" "$TOOLTIP" "$TEMP_CLASS" "$WEATHER_CLASS"
