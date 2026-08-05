#!/usr/bin/env fish
# Instala y configura el plugin claude-pulse (barra de estado de Claude Code)
# con la misma personalización usada en la laptop original.

if not command -q claude
    echo "claude CLI no encontrado en PATH. Instala Claude Code primero."
    exit 1
end

echo "Agregando marketplace claude-pulse..."
claude plugin marketplace add NoobyGains/claude-pulse

echo "Instalando plugin claude-pulse..."
claude plugin install claude-pulse@claude-pulse

set -l config_dir $HOME/.config/claude-status
mkdir -p $config_dir

echo "Escribiendo config personalizado en $config_dir/config.json..."
echo '{
  "cache_ttl_seconds": 60,
  "theme": "ember",
  "text_color": "yellow",
  "animate": "off",
  "animation_speed": "normal",
  "bar_size": "small",
  "bar_style": "classic",
  "layout": "standard",
  "max_width": 80,
  "context_format": "percent",
  "weekly_timer_format": "auto",
  "clock_format": "24h",
  "extra_display": "auto",
  "currency": "MXN",
  "peak_hours": {
    "enabled": false,
    "start": "13:00",
    "end": "19:00",
    "weekdays_only": true
  },
  "show": {
    "session": true,
    "weekly": true,
    "context": true,
    "timer": true,
    "weekly_timer": true,
    "cost": false,
    "model": true,
    "branch": true,
    "heartbeat": true,
    "activity": true,
    "update": true,
    "claude_update": true,
    "opus": true,
    "sonnet": false,
    "effort": true,
    "worktree": true,
    "pomodoro": true,
    "context_warning": true,
    "staleness": true,
    "plan": false,
    "extra": false,
    "burn_rate": false,
    "sessions": false,
    "last_tool": false,
    "sparkline": false,
    "runway": false,
    "status_message": false,
    "streak": false,
    "pace": false,
    "git_drift": false,
    "files_changed": false,
    "lines": true,
    "cumulative_cost": false
  }
}' > $config_dir/config.json

echo "Registrando statusLine en ~/.claude/settings.json..."
set -l script_path (find $HOME/.claude/plugins -type f -name claude_status.py -path "*claude-pulse*" | head -n 1)

if test -z "$script_path"
    echo "No se encontró claude_status.py tras la instalación. Corre '/pulse setup' manualmente dentro de Claude Code."
    exit 1
end

python3 "$script_path" --install

echo "Listo. Reinicia Claude Code (o abre una nueva sesión) para ver la barra de estado."
