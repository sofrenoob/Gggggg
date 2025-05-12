
set -euo pipefail

# ──────── CONFIGURAÇÃO ─────────
ZIP_URL="https://github.com/sofrenoob/Gggggg/raw/main/4/alfa_cloud.zip"
APP_DIR="/var/www/alfa_cloud"
PORT=5000
WSGI_MODULE="app:app"         # módulo:app para Gunicorn
PYTHON_IMAGE="python:3.8-slim"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${GREEN}== Deploy Alfa Cloud via Docker ==${NC}"

# 1) Pergunta a senha do admin
while true; do
  read -s -p "Nova senha para usuário 'admin': " PASS1; echo
  read -s -p "Confirme a senha: " PASS2; echo
  [[ "$PASS1" == "$PASS2" ]] && break
  echo -e "${RED}As senhas não conferem. Tente novamente.${NC}"
done
ADMIN_PASS="$PASS1"

# 2) Instala dependências de sistema
echo -e "${GREEN}Instalando dependências no host...${NC}"
apt update -y
apt install -y git wget unzip sqlite3 python3-pip \
               ca-certificates curl gnupg lsb-release

# instala Docker se não estiver
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
# instala Docker Compose plugin V2
apt install -y docker-compose-plugin
systemctl enable --now docker

# 3) Baixa e extrai o ZIP do seu projeto
echo -e "${GREEN}Baixando e extraindo o projeto...${NC}"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cd "$APP_DIR"
wget -q "$ZIP_URL" -O app.zip
unzip -q app.zip && rm app.zip

# Se houver subdiretório wrapper, mova para a raiz
if [[ ! -d app && -d alfa_cloud* ]]; then
  WRAP=$(find . -maxdepth 1 -type d -name "alfa_cloud*" | head -n1)
  mv "$WRAP"/* . && rm -rf "$WRAP"
fi

# 4) Cria o DB se não existir, detectando factory ou instância
DBFILE=$(find "$APP_DIR" -type f -iname '*.db' | head -n1 || true)
if [[ -z "$DBFILE" ]]; then
  echo -e "${GREEN}Nenhum .db encontrado; criando via db.create_all()...${NC}"
  docker run --rm -v "$APP_DIR":/app -w /app $PYTHON_IMAGE bash -lc "\
    apt update -y >/dev/null 2>&1 && apt install -y python3-pip >/dev/null 2>&1 && \
    pip install --no-cache-dir flask flask-sqlalchemy 'SQLAlchemy<2.0' 'Werkzeug<2.1' >/dev/null 2>&1 && \
    python - << 'PYCODE'
import sys
# tenta padrão factory
try:
    from app import create_app, db
    flask_app = create_app()
except Exception:
    # tenta instância direta
    import app as app_module
    if hasattr(app_module, 'db'):
        db = app_module.db
    else:
        print('ERRO: db não encontrado em app_module', file=sys.stderr); sys.exit(1)
    # encontra variável Flask atribuindo ao app
    if hasattr(app_module, 'app'):
        flask_app = app_module.app
    else:
        # procura qualquer objeto com app_context()
        for o in vars(app_module).values():
            if hasattr(o, 'app_context'):
                flask_app = o
                break
        else:
            print('ERRO: instância Flask não encontrada', file=sys.stderr); sys.exit(1)
# importa models para registrar todas as tabelas
try:
    import app.models
except:
    pass
# cria tabelas
with flask_app.app_context():
    db.create_all()
PYCODE
  "
  DBFILE=$(find "$APP_DIR" -type f -iname '*.db' | head -n1)
  if [[ -z "$DBFILE" ]]; then
    echo -e "${RED}❌ Falha ao criar o banco (.db não encontrado).${NC}"
    exit 1
  fi
  echo -e "${GREEN}Banco criado em: $DBFILE${NC}"
else
  echo -e "${GREEN}Banco existente encontrado em: $DBFILE${NC}"
fi

# 5) Atualiza senha do admin no DB
echo -e "${GREEN}Gerando hash da nova senha...${NC}"
HASH=$(docker run --rm $PYTHON_IMAGE bash -lc "\
  pip install --no-cache-dir Werkzeug >/dev/null 2>&1 && \
  python - << 'HCODE'
from werkzeug.security import generate_password_hash
print(generate_password_hash('$ADMIN_PASS'))
HCODE
")
echo -e "${GREEN}Atualizando senha no banco...${NC}"
sqlite3 "$DBFILE" "UPDATE users SET password='$HASH' WHERE username='admin';"

# 6) Gera Dockerfile
echo -e "${GREEN}Criando Dockerfile...${NC}"
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

# 7) Gera docker-compose.yml
echo -e "${GREEN}Criando docker-compose.yml...${NC}"
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
echo -e "${GREEN}Buildando e subindo o container...${NC}"
docker compose up -d --build

echo -e "${GREEN}✅ Deploy concluído!${NC}"
echo -e "   • Acesse: http://<SEU_IP>:$PORT"
echo -e "   • Logs: docker compose logs -f"
