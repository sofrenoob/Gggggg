#!/bin/bash

# Alfa Proxy Hunter 🚀 Termux Safe + Exibição Interativa

TMP_DIR="$HOME/alfa_tools/tmp"
mkdir -p "$TMP_DIR"

PROXY_VALID="$HOME/storage/downloads/proxies_validos.txt"

# Intervalo de IP para a varredura (exemplo: 100.10.10.10 até 100.10.10.20)
START_IP="100.10.10.10"
END_IP="100.10.10.20"

# Função para converter IP para número
ip_to_int() {
  local ip=$1
  local a b c d
  IFS=. read -r a b c d <<< "$ip"
  echo "$((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))"
}

# Função para converter número para IP
int_to_ip() {
  local num=$1
  echo "$((num >> 24 & 255)).$((num >> 16 & 255)).$((num >> 8 & 255)).$((num & 255))"
}

# Função para testar proxy HTTP
test_proxy() {
  local proxy=$1
  local port=$2
  local url="http://google.com"
  local code

  echo -ne "\e[33m[+] Testando $proxy:$port...\e[0m "

  code=$(curl -x "$proxy:$port" -s --max-time 5 -o /dev/null -w "%{http_code}" --connect-timeout 5 -L "$url")

  if [[ "$code" == "200" || "$code" == "101" ]]; then
    echo -e "\e[32m✅ Código $code\e[0m"
    echo "$proxy:$port" >> "$PROXY_VALID"
  else
    echo -e "\e[31m❌ Código $code\e[0m"
  fi
}

# Limpa arquivo de válidos
> "$PROXY_VALID"

# Converte os IPs para números inteiros
start_num=$(ip_to_int "$START_IP")
end_num=$(ip_to_int "$END_IP")

echo -e "\n\e[36m==== Alfa Proxy Hunter 🚀 Iniciando varredura de $START_IP até $END_IP ====\e[0m"

# Loop pelos IPs
for ((i = start_num; i <= end_num; i++)); do
  ip=$(int_to_ip $i)
  for port in 80 8080 443; do
    test_proxy "$ip" "$port"
  done
done

echo -e "\n\e[36m==== Varredura finalizada! Proxies válidos salvos em:\e[0m $PROXY_VALID"
echo -e "\e[36m====================================================\e[0m"
