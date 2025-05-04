#!/bin/bash

# Alfa Proxy Hunter Installer 🚀 by AlfaBot

echo "🔐 Configurando permissões de armazenamento..."
termux-setup-storage

echo "📁 Criando diretório para o script..."
mkdir -p $HOME/alfa_tools

echo "⬇️ Baixando Alfa Proxy Hunter..."
curl -L -o $HOME/alfa_tools/alfa_proxy_hunter.sh "https://raw.githubusercontent.com/sofrenoob/Gggggg/main/h/alfa_proxy_hunter.sh"

echo "🔓 Dando permissão de execução..."
chmod +x $HOME/alfa_tools/alfa_proxy_hunter.sh

echo "🚀 Executando o script agora..."
bash $HOME/alfa_tools/alfa_proxy_hunter.sh
