#!/bin/bash

clear
figlet "Checker Proxy" | lolcat

# Lê lista de proxies
proxies=$(cat output/proxy_ativos.txt)

echo -e "\033[1;33mTestando proxies ativos...\033[0m"

# Limpa arquivo anterior
> output/checker_ok.txt

# Testa cada proxy
for proxy in $proxies; do
  response=$(curl -x $proxy -s --max-time 5 -o /dev/null -w "%{http_code}" http://example.com)
  if [[ "$response" == "200" || "$response" == "101" ]]; then
    echo "$proxy" >> output/checker_ok.txt
    echo -e "\033[1;32m$proxy OK!\033[0m"
  else
    echo -e "\033[1;31m$proxy inválido\033[0m"
  fi
done

echo -e "\033[1;34mProxies válidos salvos em output/checker_ok.txt\033[0m"
sleep 2
bash menu.sh
