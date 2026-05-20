#!/usr/bin/env fish

# Función para obtener la IP pública
function get_public_ip
    set public_ip (curl -s https://api.ipify.org)
    if test $status -eq 0 -a -n "$public_ip"
        echo "🌐 Public IP: $public_ip"
    else
        echo "🌐 Public IP: No disponible (sin conexión)"
    end
end

# Función para obtener la IP local
function get_local_ip
    set local_ip ""
    switch (uname -s)
        case Linux
            set local_ip (ip -4 addr show | grep inet | grep -v '127.0.0.1' | head -n 1 | awk '{print $2}' | cut -d'/' -f1)
        case Darwin
            set local_ip (ifconfig | grep 'inet ' | grep -v '127.0.0.1' | head -n 1 | awk '{print $2}')
        case 'CYGWIN*' 'MSYS*' Windows
            set local_ip (powershell.exe -Command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike '*Loopback*' } | Select-Object -First 1).IPAddress" 2>/dev/null)
        case '*'
            set local_ip "No detectado"
    end

    if test -n "$local_ip"
        echo "🏠 Local IP: $local_ip"
    else
        echo "🏠 Local IP: No disponible"
    end
end

# Función para mostrar ambas IPs
function get_ip
    echo ""
    get_public_ip
    get_local_ip
    echo ""
end
