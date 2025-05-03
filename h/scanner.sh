#!/bin/bash

clear
figlet "Scanner" | lolcat

# Detectar IP e operadora
ip addr | grep inet | lolcat
getprop gsm.operator.alpha | lolcat

# Simular busca de proxies
echo -e "\033[1;34mBuscando proxies na rede...\033[0m"
curl -s https://api.proxyscrape.com/v2/?request=getproxies&protocol=http&timeout=1000&country=all > output/proxy_ativos.txt

echo -e "\033[1;32mProxies salvos em output/proxy_ativos.txt\033[0m"
sleep 2
bash menu.sh
