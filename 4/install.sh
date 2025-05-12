
set -euo pipefail

# ─────────────── PARÂMETROS ─────────────────
ZIP_URL="https://github.com/sofrenoob/Gggggg/raw/main/4/alfa_cloud.zip"
APP_DIR="/var/www/alfa_cloud"
PORT=5000
WSGI_MODULE="app:app"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${GREEN}== Deploy Alfa Cloud via Docker ==${NC}"

# 1) Pergunta senha do admin
while true; do
  read -s -p "Nova senha para usuário admin: " PASS1; echo
  read -s -p "Confirme a senha: " PASS2; echo
  [[ "$PASS1" == "$PASS2" ]] && break
  echo -e "${RED}Senhas não batem, tente de novo.${NC}"
done
ADMIN_PASS="$PASS1"

# 2) Instala pré-requisitos no host
echo -e "${GREEN}Instalando pré-requisitos...${NC}"
apt update
apt install -y git unzip sqlite3 \
   python3-pip \
   # Docker & Compose V2 plugin
   ca-certificates curl gnupg lsb-release

if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
apt install -y docker-compose-plugin
systemctl enable --now docker

# 3) Baixa e descompacta o ZIP
echo -e "${GREEN}Baixando e extraindo o projeto...${NC}"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cd "$APP_DIR"
wget -q "$ZIP_URL" -O app.zip
unzip -q app.zip; rm app.zip

# Se houver um subdir wrapper, mova os arquivos
if [[ ! -d app ]]; then
  WRAP=$(find . -maxdepth 1 -type d -name "alfa_cloud*" | head -n1)
  [[ -n $WRAP ]] && mv "$WRAP"/* . && rm -rf "$WRAP"
fi

# 4) Localiza o arquivo .db e atualiza a senha do admin
DBFILE=$(find "$APP_DIR/db" -maxdepth 1 -name "*.db" | head -n1)
if [[ -z "$DBFILE" ]]; then
  echo -e "${RED}Arquivo .db não encontrado em $APP_DIR/db${NC}"
  exit 1
fi

echo -e "${GREEN}Gerando hash da senha via Docker temporário...${NC}"
HASH=$(docker run --rm python:3.8-slim bash -lc "\
  pip install Werkzeug >/dev/null 2>&1 && \
  python -c \"from werkzeug.security import generate_password_hash; print(generate_password_hash('$ADMIN_PASS'))\"\
")

echo -e "${GREEN}Atualizando senha no banco ($DBFILE)...${NC}"
sqlite3 "$DBFILE" "UPDATE users SET password='$HASH' WHERE username='admin';"

# 5) Cria Dockerfile
echo -e "${GREEN}Criando Dockerfile...${NC}"
cat > Dockerfile <<EOF
FROM python:3.8-slim

RUN apt update && apt install -y \\
    pkg-config libcairo2-dev \\
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

RUN pip install --upgrade pip setuptools wheel \\
 && pip install -r requirements.txt

EXPOSE ${PORT}
CMD ["gunicorn","--workers","3","--bind","0.0.0.0:${PORT}","${WSGI_MODULE}"]
EOF

# 6) Cria docker-compose.yml
echo -e "${GREEN}Criando docker-compose.yml...${NC}"
cat > docker-compose.yml <<EOF
version: "3.8"
services:
  alfa_cloud:
    build: .
    ports:
      - "${PORT}:${PORT}"
    restart: unless-stopped
EOF

# 7) Builda e sobe o container
echo -e "${GREEN}Buildando e subindo o container...${NC}"
docker compose up -d --build

echo -e "${GREEN}✅ Deploy concluído!${NC}"
echo -e "   • Acesse: http://<SEU_IP>:${PORT}"
echo -e "   • Logs: docker compose logs -f"
