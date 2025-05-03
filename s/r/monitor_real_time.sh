#!/bin/bash

# Monitor AlfaMenager em tempo real
# by @alfalemos 👾🥷

LOG_FILE="logs/conexoes.log"

screen -dmS monitor tail -f $LOG_FILE
echo -e "\e[1;32m[+] Monitor de conexões ativo via screen. Use 'screen -r monitor' pra acompanhar.\e[0m"
