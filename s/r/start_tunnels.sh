#!/bin/bash

# AlfaMenager Tunnel Start Script
# by @alfalemos 👾🥷

killall socat 2>/dev/null

echo -e "\e[1;32m[+] Iniciando túneis de operadoras...\e[0m"

# Vivo - 7001
screen -dmS vivo socat TCP4-LISTEN:80,reuseaddr,fork TCP4:127.0.0.1:1194
echo -e "\e[1;36m[+] Vivo túnel ativo na porta 7001\e[0m"

# Claro - 7002
screen -dmS claro socat TCP4-LISTEN:80,reuseaddr,fork TCP4:127.0.0.1:1195
echo -e "\e[1;36m[+] Claro túnel ativo na porta 7002\e[0m"

# Tim - 7003
screen -dmS tim socat TCP4-LISTEN:80,reuseaddr,fork TCP4:127.0.0.1:1196
echo -e "\e[1;36m[+] Tim túnel ativo na porta 7003\e[0m"

# BadVPN - 7300
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300
echo -e "\e[1;33m[+] BadVPN ativo na porta 7300\e[0m"

echo -e "\e[1;32m[+] Todos túneis iniciados com sucesso!\e[0m"
