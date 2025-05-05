#!/bin/bash

# Script de instalação para o projeto proxy.py

echo "Atualizando pacotes do sistema..."
sudo apt update && sudo apt upgrade -y

echo "Instalando dependências..."
sudo apt install -y python3 python3-pip git

echo "Clonando o repositório proxy.py..."
git clone https://github.com/abhinavsingh/proxy.py.git /opt/proxy.py

echo "Instalando dependências do proxy.py..."
cd /opt/proxy.py
pip3 install -r requirements.txt

echo "Dando permissões necessárias..."
chmod +x /opt/proxy.py/proxy.py

echo "Criando alias para o painel administrativo..."
echo "alias proxy-panel='python3 /opt/proxy.py/admin_panel.py'" >> ~/.bashrc
source ~/.bashrc

echo "Instalação concluída! Abrindo o painel administrativo..."
python3 /opt/proxy.py/admin_panel.py