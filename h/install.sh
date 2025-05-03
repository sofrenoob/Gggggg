#!/bin/bash

# Atualiza pacotes
pkg update -y && pkg upgrade -y

# Instala dependências
pkg install -y curl wget python figlet toilet lolcat nc nmap

# Criar pasta de saída se não existir
mkdir -p output

# Banner inicial
clear
figlet "ALFALEMOS" | lolcat
echo -e "\033[1;34mInstalando dependências e atualizações...\033[0m"
sleep 2

# Simula download de arquivos principais
echo -e "\033[1;33mBaixando arquivos do projeto...\033[0m"
wget -O menu.sh https://link_exemplo.com/menu.sh
wget -O scanner.sh https://link_exemplo.com/scanner.sh
wget -O checker_proxy.sh https://link_exemplo.com/checker_proxy.sh

# Dar permissões
chmod +x menu.sh
chmod +x scanner.sh
chmod +x checker_proxy.sh

# Simula download de outros arquivos
wget -O output/arquivo1.txt https://arquivo_exemplo_1.com

# Finaliza instalação
echo -e "\033[1;32mTodos arquivos baixados e permissões aplicadas!\033[0m"
sleep 1

# Chama menu
bash menu.sh
