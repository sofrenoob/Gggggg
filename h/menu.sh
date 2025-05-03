#!/bin/bash

clear
figlet "@ALFALEMOS" | lolcat

echo -e "\033[1;34m=========== MENU ===========\033[0m"
echo -e "\033[1;33m[1] Scanner Proxy"
echo -e "[2] Checker Proxy"
echo -e "[0] Sair\033[0m"
echo -e "\033[1;34m============================\033[0m"

read -p $'\033[1;32mEscolha uma opção: \033[0m' opt

case $opt in
  1) bash scanner.sh ;;
  2) bash checker_proxy.sh ;;
  0) exit ;;
  *) echo "Opção inválida"; sleep 1; bash menu.sh ;;
esac
