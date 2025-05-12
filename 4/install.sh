#!/bin/bash

set -e

echo "[INFO] Atualizando pacotes e instalando dependências do sistema..."
sudo apt update && sudo apt install -y python3 python3-venv python3-pip nginx unzip curl sqlite3

echo "[INFO] Criando diretório /alfa_cloud..."
sudo mkdir -p /alfa_cloud
sudo chown $USER:$USER /alfa_cloud

echo "[INFO] Baixando e extraindo projeto..."
curl -L -o alfa_cloud.zip "https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/alfa_cloud.zip"
unzip -o alfa_cloud.zip -d /alfa_cloud
rm alfa_cloud.zip

cd /alfa_cloud

echo "[INFO] Criando ambiente virtual e instalando dependências Python..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
deactivate

echo "[INFO] Criando banco de dados SQLite..."
sqlite3 alfa_cloud.db < db/create_db.sql

echo "[INFO] Configurando serviço systemd..."
sudo tee /etc/systemd/system/alfa_cloud.service > /dev/null <<EOF
[Unit]
Description=Alfa Cloud Gunicorn
After=network.target

[Service]
User=$USER
WorkingDirectory=/alfa_cloud
ExecStart=/alfa_cloud/venv/bin/gunicorn -b 127.0.0.1:5000 app.routes:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable alfa_cloud
sudo systemctl restart alfa_cloud

echo "[INFO] Configurando Nginx..."
sudo cp nginx.conf /etc/nginx/sites-available/alfa_cloud
sudo ln -sf /etc/nginx/sites-available/alfa_cloud /etc/nginx/sites-enabled/

sudo nginx -t && sudo systemctl restart nginx

echo "[SUCESSO] Instalação concluída. Acesse: http://SEU_DOMÍNIO ou http://SEU_IP"
