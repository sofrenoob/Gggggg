
# Instalador do Alfa VPN – painel em TUI
# Autor: @alfalemos
# Execução: sudo ./install.sh
set -euo pipefail

# ------------------------------
# Variáveis – altere se quiser
# ------------------------------
INSTALL_DIR="/opt/alfa_vpn"
PY_FILE="alfa_vpn.py"
YAML_FILE="services.yml"

# Links (exemplos).  Use SEUS URLs reais ou GitHub raw.
PY_URL_1="https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/alfa_vpn.py"
PY_URL_2="https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/alfa_vpn.py"
YAML_URL_1="https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/services.yml"
YAML_URL_2="https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/services.yml"

# ------------------------------
echo "[1/6] Verificando root ..."
if [[ $EUID -ne 0 ]]; then
   echo "Este script precisa ser executado como root."; exit 1
fi

# ------------------------------
echo "[2/6] Atualizando pacotes + dependências ..."
if command -v apt &>/dev/null; then
    PKG_INSTALL="apt -y install"
    apt update -y
elif command -v yum &>/dev/null; then
    PKG_INSTALL="yum -y install"
    yum makecache -y
elif command -v dnf &>/dev/null; then
    PKG_INSTALL="dnf -y install"
    dnf makecache -y
else
    echo "Gerenciador de pacotes desconhecido (apt/yum/dnf)."; exit 1
fi
$PKG_INSTALL python3 python3-pip curl tmux

pip3 install --upgrade rich psutil pyyaml questionary

# ------------------------------
download_file () {
    local url1="$1" url2="$2" dest="$3"
    echo "  • Baixando $dest ..."
    if curl -fsSL "$url1" -o "$dest"; then
        echo "    (ok) $url1"
    elif curl -fsSL "$url2" -o "$dest"; then
        echo "    (ok) $url2"
    else
        echo "Falha ao baixar $dest"; exit 1
    fi
}

echo "[3/6] Obtendo arquivos do Alfa VPN ..."
mkdir -p "$INSTALL_DIR"
download_file "$PY_URL_1" "$PY_URL_2"  "$INSTALL_DIR/$PY_FILE"
download_file "$YAML_URL_1" "$YAML_URL_2" "$INSTALL_DIR/$YAML_FILE"
chmod +x "$INSTALL_DIR/$PY_FILE"

# ------------------------------
echo "[4/6] Criando serviço systemd ..."
SERVICE_FILE=/etc/systemd/system/alfa_vpn.service
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Painel Alfa VPN (TUI em tmux)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/tmux new-session -s ALFAVPN -d "python3 $INSTALL_DIR/$PY_FILE && sleep 2"
ExecStop=/usr/bin/tmux kill-session -t ALFAVPN
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now alfa_vpn.service

# ------------------------------
echo "[5/6] Permissões de segurança ..."
chown -R root:root "$INSTALL_DIR"
chmod 700 "$INSTALL_DIR"

# ------------------------------
echo "[6/6] Concluído!"
echo "O painel Alfa VPN já está em execução dentro de uma sessão tmux."
echo "Para acessá-lo digite:  tmux attach -t ALFAVPN"
echo "Para sair e deixar rodando: pressione  Ctrl+b  depois  d"
echo "Para interromper o serviço: systemctl stop alfa_vpn"
echo "Bom uso!"
