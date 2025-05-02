#!/bin/bash

# Garante que o diretório /root/bin exista e tenha permissões adequadas
if [ ! -d "/root/bin" ]; then
  mkdir -p /root/bin
  chmod 700 /root/bin
fi

RESULTS_TXT="/root/bin/resultado_final.txt"
RESULTS_JSON="/root/bin/resultado_final.json"
TMP_RESULTS="/tmp/rede_temp_results.txt"

# Cria os arquivos de resultado com permissões restritas (apenas root)
touch "$RESULTS_TXT" "$RESULTS_JSON"
chmod 600 "$RESULTS_TXT" "$RESULTS_JSON"

save_result() {
  local mensagem="$1"
  local ip="$2"
  local url="$3"
  local status="$4"
  echo "$mensagem" | tee -a "$RESULTS_TXT" >/dev/null
  if [ ! -s "$RESULTS_JSON" ]; then
    echo "[]" > "$RESULTS_JSON"
  fi
  tmp_json=$(mktemp)
  jq ". += [{\"ip\": \"$ip\", \"url\": \"$url\", \"status\": \"$status\"}]" "$RESULTS_JSON" > "$tmp_json" && mv "$tmp_json" "$RESULTS_JSON"
}

scan_local_network() {
  echo "[*] Varredura da rede local..."
  local subnet
  subnet=$(ip route | grep kernel | grep -oP 'src\s+\K[\d.]+')
  subnet="${subnet%.*}.0/24"
  nmap -p 80,443,8080 -oG - "$subnet" | grep "Status: Up" | awk '{print $2}' > "$TMP_RESULTS"
  cat "$TMP_RESULTS"
}

query_public_dns() {
  echo "[*] Consultando DNS públicos..."
  for dns in 8.8.8.8 1.1.1.1 9.9.9.9; do
    dig @"$dns" github.com +short | while read ip; do
      if [[ -n "$ip" ]]; then
        save_result "DNS $dns => $ip" "$dns" "github.com" "DNS"
      fi
    done
  done
}

fetch_and_test_proxies() {
  echo "[*] Buscando proxies públicos..."
  curl -s "https://api.proxyscrape.com/v2/?request=getproxies&protocol=http&timeout=3000&country=all" > /tmp/proxies.txt
  while read -r proxy; do
    [ -z "$proxy" ] && continue
    status=$(curl -x "$proxy" -s -o /dev/null -w "%{http_code}" http://example.com --max-time 5)
    if [[ "$status" == "200" || "$status" == "101" ]]; then
      echo "Proxy $proxy responde com $status"
      save_result "Proxy $proxy $status" "$proxy" "http://example.com" "$status"
    fi
  done < /tmp/proxies.txt
}

massive_ip_scan() {
  echo "[*] Scan massivo de IPs (10.10.10.10-10.10.10.20)..."
  for i in {10..20}; do
    ip="10.10.10.$i"
    for port in 80 443 8080; do
      status=$(curl -sk --max-time 3 -o /dev/null -w "%{http_code}" "http://$ip:$port")
      if [[ "$status" == "200" || "$status" == "101" ]]; then
        echo "$ip:$port responde com $status"
        save_result "$ip:$port $status" "$ip" "http://$ip:$port" "$status"
      fi
    done
  done
}

test_popular_cdns() {
  echo "[*] Testando CDNs populares..."
  cdns=( "cdn.cloudflare.com" "cdn.jsdelivr.net" "cdnjs.cloudflare.com" )
  for cdn in "${cdns[@]}"; do
    for port in 80 443 8080; do
      proto="http"
      [ "$port" -eq 443 ] && proto="https"
      status=$(curl -sk --max-time 5 -o /dev/null -w "%{http_code}" "$proto://$cdn:$port")
      if [[ "$status" == "200" || "$status" == "101" ]]; then
        echo "$cdn:$port responde com $status"
        save_result "$cdn:$port $status" "$cdn" "$proto://$cdn:$port" "$status"
      fi
    done
  done
}

menu() {
  while true; do
    echo "===== MENU REDE TOOL ====="
    echo "1) Varredura de rede local"
    echo "2) Consulta DNS públicos"
    echo "3) Buscar e testar proxies públicos"
    echo "4) Scan massivo de IPs (10.10.10.10-10.10.10.20)"
    echo "5) Testar CDNs populares"
    echo "0) Sair"
    read -rp "Escolha uma opção: " opt
    case $opt in
      1) scan_local_network ;;
      2) query_public_dns ;;
      3) fetch_and_test_proxies ;;
      4) massive_ip_scan ;;
      5) test_popular_cdns ;;
      0) echo "Saindo..."; break ;;
      *) echo "Opção inválida!" ;;
    esac
    echo "Pressione Enter para continuar..."
    read -r
  done
}

echo "" > "$RESULTS_TXT"
echo "[]" > "$RESULTS_JSON"

chmod 700 /root/bin/rede_tool.sh

menu