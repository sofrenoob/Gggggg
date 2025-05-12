
################################################################################
# Instalador automatizado – Alfa Cloud
################################################################################

# ---- Cores ---------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Iniciando a Instalação do Alfa Cloud ===${NC}"

# ---- Verifica root -------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Por favor, rode este script como root (sudo).${NC}"
    exit 1
fi

# ---- Domínio/IP fixo -----------------------------------------------------
SERVER_ADDRESS="149.56.205.233"           # <- IP ou domínio do servidor

# ---- Variáveis do projeto -----------------------------------------------
PROJECT_NAME="alfa_cloud"
INSTALL_DIR="/var/www/${PROJECT_NAME}"
REPO_URL="https://github.com/sofrenoob/Gggggg/raw/main/4/alfa_cloud.zip"
GUNICORN_SOCKET_PORT=5000
GUNICORN_CALLABLE="app:app"                # app/__init__.py deve expor "app"

# ---- Update + dependências ----------------------------------------------
echo -e "${GREEN}Atualizando o sistema...${NC}"
apt update && apt upgrade -y

echo -e "${GREEN}Instalando dependências...${NC}"
apt install -y python3 python3-pip python3-venv nginx unzip

# ---- Cria diretório do projeto ------------------------------------------
echo -e "${GREEN}Criando diretório ${INSTALL_DIR} ...${NC}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || { echo -e "${RED}Falha ao entrar em ${INSTALL_DIR}.${NC}"; exit 1; }

# ---- Baixa o projeto -----------------------------------------------------
echo -e "${GREEN}Baixando projeto...${NC}"
wget -q "$REPO_URL" -O "${PROJECT_NAME}.zip"
if [[ $? -ne 0 ]]; then
    echo -e "${RED}Erro ao baixar o ZIP.${NC}"
    exit 1
fi

echo -e "${GREEN}Descompactando...${NC}"
unzip -q "${PROJECT_NAME}.zip"
rm -f "${PROJECT_NAME}.zip"

# Se os diretórios (app/, static/) não foram extraídos na raiz,
# provavelmente estão dentro de uma pasta "alfa_cloud-*". Move tudo pra raiz.
if [[ ! -d app || ! -d static ]]; then
    INNER_DIR=$(find . -maxdepth 1 -type d -name "${PROJECT_NAME}*" | head -n 1)
    if [[ -n "$INNER_DIR" ]]; then
        shopt -s dotglob
        mv "${INNER_DIR}/"* .
        rm -rf "$INNER_DIR"
    fi
fi

# ---- Virtualenv + requirements ------------------------------------------
echo -e "${GREEN}Criando virtualenv...${NC}"
python3 -m venv venv
source venv/bin/activate
echo -e "${GREEN}Instalando dependências Python...${NC}"
pip install --upgrade pip
if [[ -f requirements.txt ]]; then
    pip install -r requirements.txt
else
    echo -e "${RED}requirements.txt não encontrado!${NC}"
    deactivate
    exit 1
fi
deactivate

# ---- Permissões ----------------------------------------------------------
echo -e "${GREEN}Ajustando permissões...${NC}"
chown -R www-data:www-data "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"
# Banco SQLite gravável
chmod 664 db/*.db 2>/dev/null || true

# ---- Nginx ---------------------------------------------------------------
echo -e "${GREEN}Configurando Nginx...${NC}"
NGINX_CONF="/etc/nginx/sites-available/${PROJECT_NAME}"

cat > "$NGINX_CONF" <<EOL
server {
    listen 80;
    server_name ${SERVER_ADDRESS};

    location / {
        proxy_pass http://127.0.0.1:${GUNICORN_SOCKET_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /static/ {
        alias ${INSTALL_DIR}/static/;
    }
}
EOL

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
nginx -t || { echo -e "${RED}Erro na configuração do Nginx.${NC}"; exit 1; }
systemctl reload nginx

# ---- Systemd para Gunicorn ----------------------------------------------
echo -e "${GREEN}Criando serviço systemd do Gunicorn...${NC}"
SERVICE_FILE="/etc/systemd/system/${PROJECT_NAME}.service"

cat > "$SERVICE_FILE" <<EOL
[Unit]
Description=Gunicorn instance for ${PROJECT_NAME}
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=${INSTALL_DIR}
Environment="PATH=${INSTALL_DIR}/venv/bin"
ExecStart=${INSTALL_DIR}/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:${GUNICORN_SOCKET_PORT} ${GUNICORN_CALLABLE}

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable --now "${PROJECT_NAME}.service"

sleep 2
if systemctl is-active --quiet "${PROJECT_NAME}.service"; then
    echo -e "${GREEN}Servidor iniciado com sucesso!${NC}"
    echo -e "${GREEN}Acesse: http://${SERVER_ADDRESS}${NC}"
else
    echo -e "${RED}Falha ao iniciar Gunicorn. Veja: systemctl status ${PROJECT_NAME}${NC}"
    exit 1
fi

echo -e "${GREEN}Instalação concluída com êxito!${NC}"
