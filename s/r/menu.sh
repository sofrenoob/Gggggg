#!/bin/bash

# AlfaMenager Menu Interativo
# by @alfalemos 👾🥷

LOG_FILE="logs/conexoes.log"

function cabecalho() {
  clear
  echo -e "\e[1;36m"
  echo "=========================================="
  echo "      ALFA MENAGER PROXY CONTROL 🥷        "
  echo "=========================================="
  echo -e "\e[0m"
}

while true; do
  cabecalho
  echo -e "\e[1;33m[1]\e[0m Iniciar Túneis"
  echo -e "\e[1;33m[2]\e[0m Parar Túneis"
  echo -e "\e[1;33m[3]\e[0m Status dos Túneis (screen)"
  echo -e "\e[1;33m[4]\e[0m Ver Últimos 200 Logs"
  echo -e "\e[1;33m[5]\e[0m Testar Velocidade"
  echo -e "\e[1;33m[6]\e[0m Mostrar IP Externo"
  echo -e "\e[1;33m[7]\e[0m Monitorar Logs em Tempo Real"
  echo -e "\e[1;33m[8]\e[0m Reiniciar Proxy Listener"
  echo -e "\e[1;33m[9]\e[0m Sair"
  echo -e "\e[1;33m[10]\e[0m Ativar DNS Avançado"
  echo -e "\e[1;33m[11]\e[0m Iniciar Monitor Real-time"
  echo -e "\e[1;33m[12]\e[0m Ver Memória de Conexões"
  echo ""
  read -p "Escolha uma opção: " opcao

  case $opcao in
    1)
      bash start_tunnels.sh
      read -p "Pressione ENTER para voltar ao menu..."
      ;;
    2)
      killall socat badvpn-udpgw
      screen -ls | grep Detached | cut -d. -f1 | awk '{print $1}' | xargs kill
      echo -e "\e[1;31m[!] Todos túneis parados!\e[0m"
      read -p "Pressione ENTER para voltar ao menu..."
      ;;
    3)
      screen -ls
      read -p "Pressione ENTER para voltar ao menu..."
      ;;
    4)
      tail -n 200 $LOG_FILE
      read -p "Pressione ENTER para voltar ao menu..."
      ;;
    5)
      speedtest-cli --simple
      read -p "Pressione ENTER para voltar ao menu..."
      ;;
    6)
      curl ifconfig.me
      echo ""
      read -p "Pressione ENTER para voltar ao menu..."
      ;;
    7)
      tail -f $LOG_FILE
      ;;
    8)
      screen -ls | grep proxy_ | cut -d. -f1 | awk '{print $1}' | xargs kill
      bash proxy_listener.sh
      echo -e "\e[1;32m[+] Proxy reiniciado!\e[0m"
      read -p "Pressione ENTER para voltar ao menu..."
      ;;
    9)
      echo -e "\e[1;31m[!] Saindo...\e[0m"
      exit
      ;;
    10)
      bash dns_custom.sh
      read -p "ENTER..."
      ;;
    11)
      bash monitor_real_time.sh
      read -p "ENTER..."
      ;;
    12)
      jq . memory.json
      read -p "ENTER..."
      ;;
    *)
      echo -e "\e[1;31m[!] Opção inválida!\e[0m"
      sleep 1
      ;;
  esac
done
