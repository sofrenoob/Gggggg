#!/bin/bash

# Atualiza o sistema e instala dependências
pkg update -y && pkg upgrade -y
pkg install -y curl wget grep sed coreutils tsu

# Solicita permissão de acesso ao armazenamento (se necessário)
termux-setup-storage

# Baixa o script do scanner de IP e executa
cd $HOME

# Link direto para o script principal (você precisa hospedar esse arquivo em algum servidor ou pastebin)
SCAN_SCRIPT_URL="https://raw.githubusercontent.com/sofrenoob/Gggggg/main/h/scanner.sh"
curl -o scanner.sh $SCAN_SCRIPT_URL

chmod +x scanner.sh

# Executa o scanner
bash scanner.sh
