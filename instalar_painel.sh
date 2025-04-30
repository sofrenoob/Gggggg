#!/bin/bash

# Atualiza pacotes e instala dependências
apt update
apt install python3 python3-pip sqlite3 unzip wget -y

# Baixa o painel
wget -O proxy_panel.zip "https://www.dropbox.com/scl/fi/1xvggoulrfnc317658hs2/proxy_panel.zip?rlkey=b4mf5ru4rgnalpdlb8xgo4lbq&st=7spp0mhx&dl=1"

# Descompacta
unzip proxy_panel.zip
cd proxy_panel

# Dá permissão e executa instalador
chmod +x install.sh
./install.sh

# Cria serviço systemd
echo "[Unit]
Description=Painel de Administração de Proxies
After=network.target

[Service]
WorkingDirectory=/root/proxy_panel
ExecStart=/usr/bin/python3 /root/proxy_panel/app.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/painelproxy.service

# Ativa serviço no boot e inicia
systemctl daemon-reload
systemctl enable painelproxy
systemctl start painelproxy

echo "Painel instalado e rodando na porta 5000"
