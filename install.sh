#!/bin/bash

# Atualiza o sistema
apt update && apt upgrade -y

# Instala dependências
apt install -y python3 python3-pip unzip wget

# Instala Flask via pip
pip3 install flask

# Cria diretório do painel
mkdir -p /root/proxy_panel/templates
mkdir -p /root/proxy_panel/static

# Baixa o arquivo zip do painel (troque o link abaixo pelo seu link real)
wget -O /root/proxy_panel.zip "https://www.dropbox.com/scl/fi/1xvggoulrfnc317658hs2/proxy_panel.zip?rlkey=b4mf5ru4rgnalpdlb8xgo4lbq&st=l9dexxmj&dl=1"

# Descompacta o zip
unzip /root/proxy_panel.zip -d /root/

# Move arquivos para os diretórios corretos
mv /root/app.py /root/proxy_panel/
mv /root/requirements.txt /root/proxy_panel/
mv /root/install.sh /root/proxy_panel/
mv /root/templates/*.html /root/proxy_panel/templates/
mv /root/static/style.css /root/proxy_panel/static/

# Define permissões
chmod +x /root/proxy_panel/app.py

# Cria serviço systemd para rodar o painel
cat <<EOL > /etc/systemd/system/painelproxy.service
[Unit]
Description=Painel de Administração de Proxies
After=network.target

[Service]
ExecStart=/usr/bin/python3 /root/proxy_panel/app.py
WorkingDirectory=/root/proxy_panel
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOL

# Habilita e inicia o serviço
systemctl daemon-reload
systemctl enable painelproxy
systemctl start painelproxy

# Finaliza
echo "Painel instalado e rodando na porta 5000!"
