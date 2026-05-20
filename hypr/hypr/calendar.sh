#!/usr/bin/env bash
# calendar.sh — Próximo evento de Google Calendar para hyprlock
# La URL iCal se lee desde ~/.config/hypr/.calendar-url

URL_FILE="$HOME/.config/hypr/.calendar-url"
CACHE_FILE="/tmp/hyprlock-calendar.cache"
CACHE_MAX_AGE=180  # 3 minutos

if [ ! -f "$URL_FILE" ] || [ -z "$(cat "$URL_FILE" 2>/dev/null)" ]; then
  echo "Sin calendario"
  exit 0
fi

ICAL_URL=$(cat "$URL_FILE")

# Usar caché si es reciente
if [ -f "$CACHE_FILE" ]; then
  AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
  if [ "$AGE" -lt "$CACHE_MAX_AGE" ]; then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

DATA=$(curl -sf --max-time 10 "$ICAL_URL")

if [ $? -ne 0 ] || [ -z "$DATA" ]; then
  [ -f "$CACHE_FILE" ] && cat "$CACHE_FILE" && exit 0
  echo "Sin conexión"
  exit 0
fi

# Pasar datos por stdin para evitar límite de tamaño de argumentos
echo "$DATA" | python3 - <<'PYEOF'
import sys, re
from datetime import datetime, timezone

raw = sys.stdin.read()

def parse_dt(s):
    s = s.strip()
    if s.endswith('Z'):
        return datetime.strptime(s, '%Y%m%dT%H%M%SZ').replace(tzinfo=timezone.utc)
    if 'T' in s:
        try:
            return datetime.strptime(s, '%Y%m%dT%H%M%S').astimezone()
        except Exception:
            return None
    try:
        return datetime.strptime(s, '%Y%m%d').replace(tzinfo=timezone.utc)
    except Exception:
        return None

now = datetime.now(timezone.utc)
events = []

for block in re.split(r'BEGIN:VEVENT', raw)[1:]:
    summary_m = re.search(r'\nSUMMARY[^:]*:(.*)', block)
    dtstart_m = re.search(r'\nDTSTART[^:]*:(.*)', block)
    if not summary_m or not dtstart_m:
        continue

    summary = re.sub(r'\\n', ' ', summary_m.group(1).strip())
    summary = re.sub(r'\\,', ',', summary)
    dt = parse_dt(dtstart_m.group(1))
    if dt and dt > now:
        events.append((dt, summary))

if not events:
    print(" Sin eventos próximos")
    sys.exit(0)

events.sort(key=lambda x: x[0])
dt, title = events[0]

local_dt = dt.astimezone()
time_str = local_dt.strftime('%H:%M')

delta = dt - now
total_min = int(delta.total_seconds() // 60)

if total_min < 60:
    remaining = f"en {total_min} min"
elif total_min < 120:
    remaining = f"en 1h {total_min % 60}min"
else:
    remaining = f"en {total_min // 60}h"

title_short = title[:22] + '…' if len(title) > 22 else title
print(f" {time_str}  {title_short}\n  {remaining}")
PYEOF
