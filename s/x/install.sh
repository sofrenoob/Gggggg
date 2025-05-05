#!/bin/bash

# Script de instalação para o projeto proxy.py com integração ao repositório https://github.com/adm/

echo "Atualizando pacotes do sistema..."
sudo apt update && sudo apt upgrade -y

echo "Instalando dependências..."
sudo apt install -y python3 python3-pip git

echo "Clonando o repositório proxy.py..."
git clone https://github.com/abhinavsingh/proxy.py.git /opt/proxy.py

echo "Clonando o repositório adicional..."
git clone https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/x/admin_panel.py /opt/adm

echo "Instalando dependências do proxy.py..."
cd /opt/proxy.py
pip3 install -r requirements.txt

echo "Dando permissões necessárias..."
chmod +x /opt/proxy.py/proxy.py
chmod +x /opt/adm/*.sh

echo "Criando alias para o painel administrativo..."
echo "alias proxy-panel='python3 /opt/proxy.py/admin_panel.py'" >> ~/.bashrc
source ~/.bashrc

echo "Instalação concluída! Abrindo o painel administrativo..."
python3 /opt/proxy.py/admin_panel.py