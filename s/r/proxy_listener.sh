#!/bin/bash

# AlfaMenager Proxy Listener
# by @alfalemos 👾🥷

PORTS=(80 8080 443)
IPS_OPERADORAS="ips_operadoras.txt"
LOG_FILE="logs/conexoes.log"

function detectar_operadora() {
    local IP=$1
    local OPERADORA="Desconhecida"
    while read linha; do
        RANGE=$(echo $linha | cut -d ' ' -f1)
        NOME=$(echo $linha | cut -d ' ' -f2)
        if [[ $IP =~ $RANGE ]]; then
            OPERADORA=$NOME
            break
        fi
    done < $IPS_OPERADORAS
    echo $OPERADORA
}

# Iniciar escuta nas portas definidas
for PORTA in "${PORTS[@]}"; do
    screen -dmS proxy_$PORTA bash -c "
        while true; do
            echo -e 'HTTP/1.1 200 AlfaMenager Proxy Server\r\n' | nc -l -p $PORTA -v -q 1 | while read line; do
                IP_CLIENTE=\$(echo \$SSH_CLIENT | awk '{print \$1}')
                echo \$(date '+%d/%m/%Y %H:%M:%S') - Conexão de: \$IP_CLIENTE na porta $PORTA" >> $LOG_FILE

                OPERADORA=\$(detectar_operadora \$IP_CLIENTE)
                echo \$(date '+%d/%m/%Y %H:%M:%S') - Detected: \$OPERADORA para IP \$IP_CLIENTE" >> $LOG_FILE

                # Se payload ruim ou vazio, chama booster
                if [[ -z \$line || \${#line} -lt 10 ]]; then
                    bash booster_payload.sh \$IP_CLIENTE $PORTA
                fi
            done
        done
    "
    echo -e "\e[1;32m[+] Listener ativo na porta $PORTA\e[0m"
done
