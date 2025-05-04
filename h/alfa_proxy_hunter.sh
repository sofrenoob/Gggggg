#!/bin/bash

# Alfa Proxy Hunter 🚀 Termux Safe

TMP_DIR="$HOME/alfa_tools/tmp"
mkdir -p "$TMP_DIR"

PROXY_LIST="$TMP_DIR/proxies_lista.txt"
PROXY_VALID="$HOME/storage/downloads/proxies_validos.txt"

# Intervalo de IP para a varredura de 100.10.10.10 até 200.20.20.20 (exemplo)
START_IP="100.10.10.10"
END_IP="200.20.20.20"

# Função para gerar uma sequência de IPs
generate_ip_range() {
  local start_ip=$1
  local end_ip=$2

  # Converte os IPs para números inteiros
  local start_num=$(ip_to_int "$start_ip")
  local end_num=$(ip_to_int "$end_ip")

  # Gera IPs dentro do intervalo
  for ((i = start_num; i <= end_num; i++)); do
    echo $(int_to_ip $i)
  done
}

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

# Função para testar proxy HTTP/WS
test_proxy() {
  local proxy=$1
  local port=$2
  local url="http://google.com"
  local code

  # Teste de conexão com payload simples HTTP
  code=$(curl -x "$proxy" -s --max-time 5 -o /dev/null -w "%{http_code}" --connect-timeout 5 -L "$url:$port")

  if [[ "$code" == "200" || "$code" == "101" ]]; then
    echo "✅ Porta $port: Proxy válido"
    return 0  # Proxy válido
  else
    echo "❌ Porta $port: Proxy inválido"
    return 1  # Proxy inválido
  fi
}

# Testar proxies nas portas 80, 8080, 443
echo "[+] Buscando proxies dentro da faixa de IPs..."

> "$PROXY_VALID"

# Gera o intervalo de IPs e testa
for ip in $(generate_ip_range "$START_IP" "$END_IP"); do
  echo "Testando IP: $ip"
  for port in 80 8080 443; do
    test_proxy "$ip" "$port" && echo "$ip" >> "$PROXY_VALID"
  done
done

echo "[+] Testes finalizados!"
echo "[+] Proxies válidos salvos em: $PROXY_VALID"
