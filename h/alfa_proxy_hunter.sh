#!/bin/bash

# Alfa Proxy Hunter 🚀

API_URL="https://api.proxyscrape.com/v2/?request=getproxies&protocol=http&timeout=3000&country=all&ssl=all&anonymity=all"
OUTPUT="$HOME/Download/proxies_validos.txt"

echo "📡 Buscando lista de proxies..."
curl -s "$API_URL" -o proxies.txt

echo "🎯 Testando proxies válidos..."

> "$OUTPUT"  # Limpa o arquivo antes de começar

while read proxy; do
  if [ ! -z "$proxy" ]; then
    echo -n "Testando $proxy ... "
    code=$(curl -x "$proxy" -s --max-time 5 -o /dev/null -w "%{http_code}" http://google.com)
    if [[ "$code" == "200" || "$code" == "101" ]]; then
      echo "$proxy ✅"
      echo "$proxy" >> "$OUTPUT"
    else
      echo "falhou ❌"
    fi
  fi
done < proxies.txt

echo "✅ Teste finalizado. Proxies válidos salvos em: $OUTPUT"
