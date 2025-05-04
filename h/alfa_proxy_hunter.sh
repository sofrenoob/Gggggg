#!/bin/bash

# Alfa Proxy Hunter v1.0 - by @Alfalemos 🚀

# Caminho para salvar os proxies válidos
output="$HOME/storage/downloads/proxies_validos.txt"

# APIs de proxy
apis=(
"https://api.proxyscrape.com/?request=getproxies&proxytype=http&timeout=2000"
"https://www.proxy-list.download/api/v1/get?type=http"
"https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/http.txt"
)

# Pegar proxies e salvar em lista temporária
tmp_proxies="/tmp/proxies_lista.txt"
> "$tmp_proxies"

echo "[+] Buscando proxies..."
for api in "${apis[@]}"; do
    curl -s "$api" >> "$tmp_proxies"
done

# Remover linhas vazias e duplicadas
sort -u "$tmp_proxies" | sed '/^$/d' > "$tmp_proxies.clean"
mv "$tmp_proxies.clean" "$tmp_proxies"

echo "[+] Testando proxies para CONNECT na porta 22 e 80..."
> "$output"

# Função para testar proxy
test_proxy() {
    proxy=$1
    ip=$(echo $proxy | cut -d':' -f1)
    port=$(echo $proxy | cut -d':' -f2)

    timeout 3 bash -c "echo > /dev/tcp/$ip/80" 2>/dev/null && echo "[OK] $proxy porta 80" >> "$output"
    timeout 3 bash -c "echo > /dev/tcp/$ip/22" 2>/dev/null && echo "[OK] $proxy porta 22" >> "$output"
}

# Ler proxies e testar um por um
while read proxy; do
    test_proxy "$proxy" &
done < "$tmp_proxies"

wait
echo "[+] Testes finalizados!"
echo "[+] Proxies válidos salvos em: $output"
