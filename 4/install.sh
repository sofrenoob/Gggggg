
set -euo pipefail

# ──────── CONFIGURAÇÃO ─────────
ZIP_URL="https://github.com/sofrenoob/Gggggg/raw/main/4/alfa_cloud.zip"
APP_DIR="/var/www/alfa_cloud"
DB_SQL_PATH="db/create_db.sql"      # caminho relativo ao root do projeto
DB_FILE_NAME="alfa_cloud.db"        # nome que o arquivo SQLite vai ter
PORT=5000
WSGI_MODULE="app:app"
PYTHON_IMAGE="python:3.8-slim"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${GREEN}== Deploy Alfa Cloud via Docker usando create_db.sql ==${NC}"

# 1) Pergunta senha do admin
while true; do
  read -s -p "Nova senha para usuário 'admin': " PASS1; echo
  read -s -p "Confirme a senha: " PASS2; echo
  [[ "$PASS1" == "$PASS2" ]] && break
  echo -e "${RED}As senhas não conferem. Tente novamente.${NC}"
done
ADMIN_PASS="$PASS1"

# 2) Instala deps de sistema
echo -e "${GREEN}Instalando dependências no host…${NC}"
apt update -y
apt install -y git wget unzip sqlite3 python3-pip \
               ca-certificates curl gnupg lsb-release
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
apt install -y docker-compose-plugin
systemctl enable --now docker

# 3) Baixa e extrai o ZIP
echo -e "${GREEN}Baixando e extraindo o projeto…${NC}"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cd "$APP_DIR"
wget -q "$ZIP_URL" -O project.zip
unzip -q project.zip && rm project.zip

# corrige subpasta wrapper (se existir)
if [[ ! -d app && -d alfa_cloud* ]]; then
  WRAP=$(find . -maxdepth 1 -type d -name "alfa_cloud*" | head -n1)
  mv "$WRAP"/* . && rm -rf "$WRAP"
fi

# 4) Cria o DB via SQL
SQLFILE="$APP_DIR/$DB_SQL_PATH"
DBDIR="$APP_DIR/$(dirname $DB_SQL_PATH)"
DBFILE="$DBDIR/$DB_FILE_NAME"

if [[ ! -f "$SQLFILE" ]]; then
  echo -e "${RED}ERRO: não encontrei $SQLFILE. Abortando.${NC}"
  exit 1
fi

echo -e "${GREEN}Criando o banco via $SQLFILE…${NC}"
mkdir -p "$DBDIR"
rm -f "$DBFILE"
sqlite3 "$DBFILE" < "$SQLFILE"
if [[ ! -f "$DBFILE" ]]; then
  echo -e "${RED}❌ Falha ao criar $DBFILE${NC}"
  exit 1
fi
echo -e "${GREEN}Banco criado em: $DBFILE${NC}"

# 5) Atualiza senha do admin na tabela admins
echo -e "${GREEN}Gerando hash da nova senha…${NC}"
HASH=$(docker run --rm $PYTHON_IMAGE bash -lc "\
  pip install --no-cache-dir Werkzeug >/dev/null 2>&1 && \
  python - << 'EOF'
from werkzeug.security import generate_password_hash
print(generate_password_hash('$ADMIN_PASS'))
EOF
")
echo -e "${GREEN}Atualizando senha na tabela 'admins'…${NC}"
sqlite3 "$DBFILE" "UPDATE admins SET password='$HASH' WHERE username='admin';"

# 6) Cria Dockerfile
echo -e "${GREEN}Criando Dockerfile…${NC}"
cat > Dockerfile <<EOF
FROM $PYTHON_IMAGE

RUN apt update && apt install -y \\
    pkg-config libcairo2-dev \\
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

RUN pip install --upgrade pip setuptools wheel \\
 && pip install -r requirements.txt

EXPOSE $PORT
CMD ["gunicorn","--workers","3","--bind","0.0.0.0:$PORT","$WSGI_MODULE"]
EOF

# 7) Cria docker-compose.yml
echo -e "${GREEN}Criando docker-compose.yml…${NC}"
cat > docker-compose.yml <<EOF
version: "3.8"
services:
  alfa_cloud:
    build: .
    ports:
      - "$PORT:$PORT"
    restart: unless-stopped
EOF

# 8) Build e deploy
echo -e "${GREEN}Buildando e subindo o container…${NC}"
docker compose up -d --build

echo -e "${GREEN}✅ Deploy concluído!${NC}"
echo -e "   • Acesse: http://<SEU_IP>:$PORT"
echo -e "   • Logs: docker compose logs -f"
