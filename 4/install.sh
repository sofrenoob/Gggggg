
set -euo pipefail

# ───── CONFIG ─────────────────────────────────────────────────────────
PANEL_ROOT=/opt/serverpanel
REPO_ZIP="https://github.com/sofrenoob/Gggggg/raw/main/4/painel.zip"  # URL do ZIP
HTTP_PORT=8080

# ───── 1) Pacotes básicos ─────────────────────────────────────────────
echo "==> Instalando pacotes base..."
apt update -qq
DEBIAN_FRONTEND=noninteractive apt install -yq \
  python3 python3-venv python3-pip unzip wget curl ufw \
  build-essential cmake gcc libsodium-dev psmisc screen socat stunnel4 squid openvpn

# ───── 2) Download e extração do painel ──────────────────────────────
echo "==> Baixando e extraindo o painel..."
rm -rf "$PANEL_ROOT"
mkdir -p /tmp/painel_src

wget -qO /tmp/painel.zip "$REPO_ZIP"
unzip -q /tmp/painel.zip -d /tmp/painel_src

# Detecta se unzip criou um único subdiretório
entries=(/tmp/painel_src/*)
if [ "${#entries[@]}" -eq 1 ] && [ -d "${entries[0]}" ]; then
  mv "${entries[0]}" "$PANEL_ROOT"
else
  mkdir -p "$PANEL_ROOT"
  mv /tmp/painel_src/* "$PANEL_ROOT"/
fi

rm -rf /tmp/painel.zip /tmp/painel_src

# ───── 3) Virtualenv e pip ────────────────────────────────────────────
echo "==> Criando virtualenv..."
python3 -m venv "$PANEL_ROOT/venv"
source "$PANEL_ROOT/venv/bin/activate"

echo "==> Atualizando pip e instalando dependências..."
pip install --upgrade pip
pip install -r "$PANEL_ROOT/requirements.txt"

# ───── 4) Banco de dados e usuário ADMIN ─────────────────────────────
echo "==> Configurando banco e criando usuário ADMIN..."
export PANEL_ROOT
python3 <<'PYCODE'
import getpass, os, sys
sys.path.insert(0, os.environ['PANEL_ROOT'])
from app import create_app
from models import db, AdminUser

app = create_app()
with app.app_context():
    db.create_all()
    u = input("Usuário ADMIN: ")
    p1 = getpass.getpass("Senha: ")
    p2 = getpass.getpass("Confirme a senha: ")
    if p1 != p2:
        print("Erro: senhas não conferem")
        sys.exit(1)
    AdminUser.create(u, p1)
    print("Usuário ADMIN criado com sucesso.")
PYCODE

# ───── 5) Service systemd ────────────────────────────────────────────
echo "==> Criando serviço systemd..."
cat > /etc/systemd/system/panel.service <<EOF
[Unit]
Description=ServerPanel
After=network.target

[Service]
WorkingDirectory=$PANEL_ROOT
ExecStart=$PANEL_ROOT/venv/bin/gunicorn -b 0.0.0.0:$HTTP_PORT app:create_app()
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now panel

# ───── 6) Firewall ──────────────────────────────────────────────────
echo "==> Ajustando firewall..."
if ufw status | grep -q active; then
  ufw allow $HTTP_PORT/tcp || true
fi

# ───── 7) Final ──────────────────────────────────────────────────────
IP=$(hostname -I | awk '{print $1}')
echo -e "\nPainel instalado e rodando em: http://$IP:$HTTP_PORT\n"
