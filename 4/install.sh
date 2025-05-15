#!/usr/bin/env bash
#
# Instalador automático do ServerPanel + dependências
# Testado em Ubuntu 18.04, 20.04, 22.04

set -euo pipefail

###############################
### CONFIGURÁVEIS RÁPIDOS   ###
###############################
PANEL_ROOT=/opt/serverpanel
GITHUB_ZIP_URL="https://github.com/sofrenoob/Gggggg/raw/main/4/painel.zip"  # <-- troque
HTTP_PORT=8080                # porta em que o painel ficará escutando

#####################################################
### 1. Pacotes de sistema necessários (apt)       ###
#####################################################
echo "==> Atualizando APT e instalando pacotes-base…"
apt update -qq
DEBIAN_FRONTEND=noninteractive \
apt install -yq python3 python3-venv python3-pip git ufw \
                build-essential curl wget unzip screen socat \
                stunnel4 squid openvpn cmake gcc libsodium-dev \
                psmisc

#####################################################
### 2. Baixar e descompactar o projeto             ###
#####################################################
echo "==> Baixando código-fonte…"
rm -rf "$PANEL_ROOT"
mkdir -p "$PANEL_ROOT"
TMP=$(mktemp -d)
wget -qO "$TMP/panel.zip" "$GITHUB_ZIP_URL"
unzip -q "$TMP/panel.zip" -d "$TMP"
# move tudo que estava no diretório raiz do repositório para PANEL_ROOT
mv "$TMP"/*/ "$PANEL_ROOT"
rm -rf "$TMP"

#####################################################
### 3. Ambiente virtual Python                     ###
#####################################################
echo "==> Criando virtualenv…"
python3 -m venv "$PANEL_ROOT/venv"
source "$PANEL_ROOT/venv/bin/activate"
pip install --upgrade pip
pip install -r "$PANEL_ROOT/requirements.txt"

#####################################################
### 4. Inicializar banco e criar usuário admin     ###
#####################################################
echo "==> Criando banco SQLite e usuário ADMIN…"
python - <<'PY'
import getpass, os, sys, pathlib
sys.path.insert(0, os.environ['PANEL_ROOT'] if 'PANEL_ROOT' in os.environ else '/opt/serverpanel')
from app import create_app
from models import db, AdminUser
app = create_app()
with app.app_context():
    db.create_all()
    user = input("Usuário ADMIN desejado: ")
    pwd1 = getpass.getpass("Senha: ")
    pwd2 = getpass.getpass("Confirme a senha: ")
    if pwd1 != pwd2: 
        print("Senhas não conferem!"); sys.exit(1)
    AdminUser.create(user, pwd1)
    print("✔️  Usuário admin criado.")
PY

#####################################################
### 5. Service systemd                             ###
#####################################################
echo "==> Criando unit systemd…"
cat >/etc/systemd/system/panel.service <<EOF
[Unit]
Description=ServerPanel – painel de administração de servidores
After=network.target

[Service]
User=root
WorkingDirectory=$PANEL_ROOT
Environment="PYTHONUNBUFFERED=1"
ExecStart=$PANEL_ROOT/venv/bin/gunicorn -b 0.0.0.0:$HTTP_PORT app:create_app()
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now panel.service

#####################################################
### 6. Abrir porta no UFW (opcional)               ###
#####################################################
if ufw status | grep -q active; then
    echo "==> Abrindo porta $HTTP_PORT/tcp no UFW…"
    ufw allow "$HTTP_PORT"/tcp || true
fi

#####################################################
### 7. Mensagem final                              ###
#####################################################
IP=$(hostname -I | awk '{print $1}')
echo -e "\n===================================================="
echo -e "Painel instalado e rodando!"
echo -e "URL:  http://$IP:$HTTP_PORT"
echo -e "Utilize o usuário e senha criados nos passos acima."
echo -e "===================================================="
