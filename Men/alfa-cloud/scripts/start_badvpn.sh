#!/bin/bash
echo "Iniciando BadVPN na porta 7300..."
badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 5 &
echo "BadVPN iniciado."
