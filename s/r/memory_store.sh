#!/bin/bash

# Memória de conexões AlfaMenager
# by @alfalemos 👾🥷

MEMORY_FILE="memory.json"
IP_CLIENTE=$1
OPERADORA=$2

# Se arquivo não existe, cria
if [ ! -f "$MEMORY_FILE" ]; then
  echo "[]" > $MEMORY_FILE
fi

# Adiciona nova entrada
NEW_ENTRY="{\"ip\":\"$IP_CLIENTE\",\"operadora\":\"$OPERADORA\",\"data\":\"$(date '+%d/%m/%Y %H:%M:%S')\"}"

# Insere no JSON
jq ". += [$NEW_ENTRY]" $MEMORY_FILE > tmp.$$.json && mv tmp.$$.json $MEMORY_FILE

echo -e "\e[1;32m[+] Memória atualizada: $IP_CLIENTE - $OPERADORA\e[0m"
