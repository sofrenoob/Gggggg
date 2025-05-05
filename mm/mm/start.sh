#!/bin/bash

echo "Iniciando GGProxy VPN Proxy MultiPort 🥷"

# Executa proxy_server.py nas portas definidas
for port in 80 443 8080 7300
do
  python3 /opt/ggproxy/proxy_server.py --port $port &
done

# Inicia proxy stealth all-in-one
python3 /opt/ggproxy/proxy_vpn_stealth.py &

echo "Todos os proxies ativos!"
