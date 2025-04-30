#!/bin/bash

# Instala dependências
sudo apt update
sudo apt install python3 python3-pip sqlite3 unzip wget -y

# Baixa o painel ZIP (troque o link abaixo pelo seu)
wget -O proxy_panel.zip "https://seu-servidor.com/proxy_panel.zip"

# Extrai o ZIP
unzip proxy_panel.zip
cd proxy_panel

# Torna instalador executável e executa
chmod +x install.sh
./install.sh

# Inicia o painel
python3 app.py
