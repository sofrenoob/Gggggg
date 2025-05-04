#!/bin/bash

# Alfa Proxy Hunter 🚀 Termux Safe

TMP_DIR="$HOME/alfa_tools/tmp"
mkdir -p "$TMP_DIR"

PROXY_LIST="$TMP_DIR/proxies_lista.txt"
PROXY_VALID="$HOME/storage/downloads/proxies_validos.txt"

echo "[+] Buscando proxies..."
curl -s "https://api.proxyscrape.com/v2/?request=getproxies&protocol=http&timeout=3000&country=all&ssl=all&anonymity=all" -o "$PROXY_LIST"

# Verifica se baixou algo
if [ ! -s "$PROXY_LIST" ]; then
  echo "[!] Nenhum proxy encontrado. Abortando."
  exit 1
fi

# Remove linhas vazias e ordena
grep -v '^$' "$PROXY_LIST" | sort -u > "$PROXY_LIST.clean"
mv "$PROXY_LIST.clean" "$PROXY_LIST"

echo "[+] Testando proxies para CONNECT na porta 80..."

> "$PROXY_VALID"

while read proxy; do
  echo -n "Testando $proxy... "
  code=$(curl -x "$proxy" -s --max-time 5 -o /dev/null -w "%{http_code}" http://google.com)
  if [[ "$code" == "200" || "$code" == "101" ]]; then
    echo "✅"
    echo "$proxy" >> "$PROXY_VALID"
  else
    echo "❌"
  fi
done < "$PROXY_LIST"

echo "[+] Testes finalizados!"
echo "[+] Proxies válidos salvos em: $PROXY_VALID"
