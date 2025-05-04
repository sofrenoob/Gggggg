#!/bin/bash

echo "[INFO] Atualizando pacotes e instalando dependências..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip

echo "[INFO] Baixando o painel..."
curl -o panel.py https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/r/o/panel.py

echo "[INFO] Dando permissão ao painel..."
chmod +x panel.py

echo "[INFO] Instalação concluída. Execute o painel com:"
echo "python3 panel.py"