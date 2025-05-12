
################################################################################
# Alfa Cloud
################################################################################
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
echo -e "${GREEN}=== Instalando Alfa Cloud ===${NC}"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Execute como root (sudo).${NC}"; exit 1
fi

# ─── parâmetros principais ───────────────────────────────────────────────────
PROJECT="alfa_cloud"
INSTALL_DIR="/var/www/$PROJECT"
ZIP_URL="https://github.com/sofrenoob/Gggggg/raw/main/4/alfa_cloud.zip"
GUNI_PORT=5000
CALLABLE="app:app"                # app/__init__.py → app = Flask(__name__)

# Detecta IP público
PUBLIC_IP=$(curl -s https://api.ipify.org || echo "_")
echo -e "${GREEN}IP detectado: $PUBLIC_IP${NC}"

# ─── pacotes do sistema ───────────────────────────────────────────────────────
echo -e "${GREEN}Atualizando e instalando dependências de sistema...${NC}"
apt update -y
apt install -y \
  python3 python3-venv python3-pip python3-dev \
  pkg-config libcairo2-dev python3-cairo \
  nginx unzip

# ─── obtém código ─────────────────────────────────────────────────────────────
echo -e "${GREEN}Baixando e extraindo código...${NC}"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
wget -q "$ZIP_URL" -O "$PROJECT.zip"
unzip -q "$PROJECT.zip"
rm "$PROJECT.zip"

# Se o zip criou um wrapper, descompacta para a raiz
if [[ ! -d app ]]; then
  WRAP=$(find . -maxdepth 1 -type d -name "$PROJECT*" | head -n1)
  [[ -n $WRAP ]] && mv "$WRAP"/* . && rm -rf "$WRAP"
fi

# ─── virtualenv + requirements ───────────────────────────────────────────────
echo -e "${GREEN}Configurando virtualenv e instalando libs Python...${NC}"
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip setuptools wheel

# garante pin de Werkzeug antes de instalar o resto
if ! grep -qE '^Werkzeug<2\.1' requirements.txt; then
  echo "Werkzeug<2.1" | cat - requirements.txt > tmp && mv tmp requirements.txt
fi

pip install -r requirements.txt
deactivate

# ─── permissões ───────────────────────────────────────────────────────────────
echo -e "${GREEN}Ajustando permissões...${NC}"
chown -R www-data:www-data "$INSTALL_DIR"
find "$INSTALL_DIR" -type d -exec chmod 755 {} +
find "$INSTALL_DIR" -type f -exec chmod 644 {} +
chmod 664 "$INSTALL_DIR/db/"*.db 2>/dev/null || true

# ─── nginx ───────────────────────────────────────────────────────────────────
echo -e "${GREEN}Configurando Nginx...${NC}"
NGCONF="/etc/nginx/sites-available/$PROJECT"
cat > "$NGCONF" <<EOF
server {
    listen 80;
    server_name $PUBLIC_IP;

    location / {
        proxy_pass http://127.0.0.1:$GUNI_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_redirect off;
    }

    location /static/ {
        alias $INSTALL_DIR/static/;
    }
}
EOF

ln -sf "$NGCONF" /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# ─── systemd (gunicorn) ──────────────────────────────────────────────────────
echo -e "${GREEN}Criando serviço systemd para Gunicorn...${NC}"
SERVICE="/etc/systemd/system/$PROJECT.service"
cat > "$SERVICE" <<EOF
[Unit]
Description=Gunicorn – $PROJECT
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin"
ExecStart=$INSTALL_DIR/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:$GUNI_PORT $CALLABLE
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "$PROJECT"

# ─── fim ─────────────────────────────────────────────────────────────────────
sleep 2
if systemctl is-active --quiet "$PROJECT"; then
    echo -e "${GREEN}✅ Alfa Cloud rodando em: http://$PUBLIC_IP${NC}"
else
    echo -e "${RED}❌ Algo deu errado. Veja: systemctl status $PROJECT${NC}"
fi
