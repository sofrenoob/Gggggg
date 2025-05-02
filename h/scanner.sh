#!/bin/bash

RESULT_DIR="$HOME/storage/downloads"
RESULT_FILE="$RESULT_DIR/resultados_scan.txt"

mkdir -p "$RESULT_DIR"
echo "" > "$RESULT_FILE"

scan_ip() {
    IP=$1
    for PORT in 80 443 8080 53; do
        for METHOD in GET HEAD OPTIONS TRACE; do
            RESPONSE=$(curl -m 3 -X $METHOD --http1.1 --connect-timeout 2 -s -o /dev/null -w "%{http_code}" http://$IP:$PORT)
            if [[ "$RESPONSE" == "200" || "$RESPONSE" == "101" ]]; then
                echo "$IP:$PORT [$METHOD] - HTTP/1.1 $RESPONSE" | tee -a "$RESULT_FILE"
            fi
        done
    done
}

# Range de IP inicial e final
IP_START=11
IP_END=200

# Loop pelos IPs de 11.11.11.11 até 200.200.200.200
for A in $(seq $IP_START $IP_END); do
  for B in $(seq $IP_START $IP_END); do
    for C in $(seq $IP_START $IP_END); do
      for D in $(seq $IP_START $IP_END); do
        IP="$A.$B.$C.$D"
        echo "Testando $IP..."
        scan_ip $IP
      done
    done
  done
done
