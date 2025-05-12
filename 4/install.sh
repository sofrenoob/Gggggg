#!/bin/bash

set -e

echo "[INFO] Atualizando pacotes..."
sudo apt update && sudo apt install -y nginx unzip python3-pip python3-venv certbot python3-certbot-nginx

echo "[INFO] Criando diretório /alfa_cloud..."
mkdir -p /alfa_cloud
cd /alfa_cloud

echo "[INFO] Baixando e extraindo projeto..."
curl -L https://github.com/sofrenoob/Gggggg/raw/main/4/alfa_cloud.zip -o alfa_cloud.zip
unzip -o alfa_cloud.zip
rm alfa_cloud.zip

echo "[INFO] Criando ambiente virtual e instalando dependências..."
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

echo "[INFO] Configurando banco de dados..."
sqlite3 db/alfa_cloud.db < db/create_db.sql

echo "[INFO] Criando serviço systemd para o Gunicorn..."
cat > /etc/systemd/system/alfa_cloud.service <<EOF
[Unit]
Description=Alfa Cloud Gunicorn
After=network.target

[Service]
User=root
WorkingDirectory=/alfa_cloud
ExecStart=/alfa_cloud/venv/bin/gunicorn -w 4 -b 127.0.0.1:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now alfa_cloud

echo "[INFO] Configurando Nginx..."
cat > /etc/nginx/sites-available/alfa_cloud <<EOF
server {
    listen 80;
    server_name avira.alfalemos.shop;

    location /static/ {
        alias /alfa_cloud/static/;
        expires 30d;
        access_log off;
    }

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/alfa_cloud /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

echo "[INFO] Gerando certificado SSL com Certbot..."
certbot --nginx -d avira.alfalemos.shop --non-interactive --agree-tos -m seu-email@example.com

echo "[INFO] Instalação finalizada com sucesso!"
