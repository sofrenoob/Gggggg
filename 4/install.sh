#!/bin/bash

echo "[INFO] Atualizando repositórios e instalando dependências do sistema..."
apt update
apt install -y python3 python3-venv python3-pip sqlite3 unzip nginx curl

echo "[INFO] Criando diretório /alfa_cloud..."
mkdir -p /alfa_cloud
cd /alfa_cloud || exit 1

echo "[INFO] Baixando e extraindo projeto..."
curl -o alfa_cloud.zip -L https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/alfa_cloud.zip  # Substitua pelo link correto
unzip -o alfa_cloud.zip
rm alfa_cloud.zip

echo "[INFO] Criando ambiente virtual e instalando dependências Python..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo "[INFO] Configurando banco de dados SQLite..."
if ! command -v sqlite3 &> /dev/null; then
    echo "[ERRO] sqlite3 não encontrado. A instalação falhou."
    exit 1
fi
sqlite3 db/alfa_cloud.db < db/create_db.sql

echo "[INFO] Copiando configuração do nginx..."
cp nginx.conf /etc/nginx/sites-available/alfa_cloud
ln -sf /etc/nginx/sites-available/alfa_cloud /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

echo "[INFO] Criando serviço systemd..."
cat <<EOF > /etc/systemd/system/alfa_cloud.service
[Unit]
Description=Alfa Cloud Gunicorn
After=network.target

[Service]
User=root
WorkingDirectory=/alfa_cloud
ExecStart=/alfa_cloud/venv/bin/gunicorn -b 127.0.0.1:5000 app.routes:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "[INFO] Habilitando e iniciando o serviço alfa_cloud..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable alfa_cloud
systemctl start alfa_cloud

echo "[SUCESSO] Instalação concluída. Acesse: http://SEU_DOMÍNIO ou http://SEU_IP"
