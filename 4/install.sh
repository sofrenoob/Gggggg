
# Instalador Alfa VPN – versão corrigida 2025-05-14
# Requisitos: Linux com systemd, acesso root, curl

set -euo pipefail

# ──────────────────────────────
# Configuráveis
# ──────────────────────────────
INSTALL_DIR="/opt/alfa_vpn"
PY_FILE="alfa_vpn.py"
YAML_FILE="services.yml"

# Dois links de download para cada arquivo (edite para os seus)
PY_URL_1="https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/alfa_vpn.py"
PY_URL_2="https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/alfa_vpn.py"
YAML_URL_1="https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/services.yml"
YAML_URL_2="https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/services.yml"

# ──────────────────────────────
echo "[1/7] Verificando root..."
[[ $EUID -eq 0 ]] || { echo "Execute como root."; exit 1; }

# ──────────────────────────────
echo "[2/7] Detectando gerenciador de pacotes..."
if command -v apt >/dev/null; then
    PM_UPDATE="apt update -y"
    PM_INSTALL="apt install -y"
elif command -v dnf >/dev/null; then
    PM_UPDATE="dnf makecache -y"
    PM_INSTALL="dnf install -y"
elif command -v yum >/dev/null; then
    PM_UPDATE="yum makecache -y"
    PM_INSTALL="yum install -y"
else
    echo "Nenhum apt, dnf ou yum encontrado."; exit 1
fi
eval "$PM_UPDATE"

echo "[3/7] Instalando dependências do sistema..."
$PM_INSTALL python3 python3-pip curl tmux squid pptpd apache2-utils

# ──────────────────────────────
echo "[4/7] Instalando dependências Python..."
pip3 install --upgrade --quiet rich psutil pyyaml questionary

# ──────────────────────────────
echo "[5/7] Baixando painel..."
mkdir -p "$INSTALL_DIR"

download() {         # $1=url1 $2=url2 $3=dest
    echo -n "  • $3 ... "
    if curl -fsSL "$1" -o "$3"; then
        echo "ok ($1)"
    elif curl -fsSL "$2" -o "$3"; then
        echo "ok ($2)"
    else
        echo "FALHA"
        exit 1
    fi
}

download "$PY_URL_1"   "$PY_URL_2"   "$INSTALL_DIR/$PY_FILE"
download "$YAML_URL_1" "$YAML_URL_2" "$INSTALL_DIR/$YAML_FILE"
chmod 750 "$INSTALL_DIR/$PY_FILE"

# ───────── PATCH automático caso o código remoto seja antigo ─────────
echo "[patch] Conferindo se list_user já está corrigida..."
if ! grep -q "=== Usuários PPTP" "$INSTALL_DIR/$PY_FILE"; then
    echo "Aplicando patch no alfa_vpn.py"
    sed -i '/def list_user()/,/^def /c\
def list_user():\n\
    console.print("[bold cyan]==\u003d Usuários PPTP (chap-secrets) ==\u003d[/bold cyan]")\n\
    chap=\"/etc/ppp/chap-secrets\"\n\
    if os.path.exists(chap):\n\
        with open(chap) as f:\n\
            for l in f:\n\
                if l.strip() and not l.startswith(\"#\"):\n\
                    console.print(\"• \" + l.split()[0])\n\
    else:\n\
        console.print(\"Arquivo não encontrado.\")\n\
    console.print(\"\\n[bold cyan]==\u003d Usuários Squid (basic auth) ==\u003d[/bold cyan]\")\n\
    passwd=\"/etc/squid/passwd\"\n\
    if os.path.exists(passwd):\n\
        with open(passwd) as f:\n\
            for l in f:\n\
                console.print(\"• \" + l.split(\":\")[0])\n\
    else:\n\
        console.print(\"Arquivo não encontrado.\")\n\
    input(\"\\nEnter...\")' "$INSTALL_DIR/$PY_FILE"
fi

# ──────────────────────────────
echo "[6/7] Criando arquivos de autenticação vazios (caso não existam)..."
install -o root -g root -m 600 /dev/null /etc/ppp/chap-secrets 2>/dev/null || true
touch /etc/squid/passwd
chown proxy:proxy /etc/squid/passwd
chmod 640 /etc/squid/passwd

# ──────────────────────────────
echo "[7/7] Criando/atualizando serviço systemd..."
cat > /etc/systemd/system/alfa_vpn.service <<EOF
[Unit]
Description=Painel Alfa VPN (TUI em tmux)
After=network.target

[Service]
Type=forking
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/tmux new-session -s ALFAVPN -d "/usr/bin/python3 $INSTALL_DIR/$PY_FILE"
ExecStop=/usr/bin/tmux kill-session -t ALFAVPN
RemainAfterExit=yes
KillMode=none
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now alfa_vpn.service

# ──────────────────────────────
echo
echo "────────────────── INSTALAÇÃO CONCLUÍDA ──────────────────"
echo "O painel está rodando em uma sessão tmux chamada ALFAVPN."
echo "Comandos úteis:"
echo "    tmux attach -t ALFAVPN        # abrir o painel"
echo "    Ctrl+b  d                     # (dentro do tmux) sair mantendo execução"
echo "    systemctl restart alfa_vpn    # reiniciar painel"
echo "    systemctl stop alfa_vpn       # parar painel"
echo "────────────────────────────────────────────────────────────"
