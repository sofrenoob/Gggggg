#!/bin/bash

REPO_URL="https://raw.githubusercontent.com/sofrenoob/Gggggg/main/mm/mm/h/hsproxy-pro-v2.sh"
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="hsproxy"

echo "[INFO] Baixando o HSProxy Pro v2 do repositório..."
curl -fsSL "$REPO_URL" -o "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

echo "[OK] HSProxy instalado com sucesso!"
echo "Você pode iniciar com: sudo $SCRIPT_NAME"
