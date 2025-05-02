#!/bin/bash

set -e

echo "=== Instalador do Rede Tool ==="
echo

# Caminho do diretório de instalação
INSTALL_DIR="/root/bin"

if [ "$(id -u)" -ne 0 ]; then
  echo "Por favor, execute este instalador como root (sudo bash install.sh)"
  exit 1
fi

# Exemplo de download do projeto como ZIP do GitHub
# echo "- Baixando pacote do GitHub..."
# wget https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/r/rede_tool.sh -O /tmp/rede_tool.sh
# cp /tmp/rede_tool.sh ./

# Copia o script principal para o diretório correto
echo "- Copiando arquivos para $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp rede_tool.sh "$INSTALL_DIR/"
chmod 700 "$INSTALL_DIR/rede_tool.sh"

# Cria arquivos de resultado vazios e ajusta permissões
touch "$INSTALL_DIR/resultado_final.txt" "$INSTALL_DIR/resultado_final.json"
chmod 600 "$INSTALL_DIR/resultado_final.txt" "$INSTALL_DIR/resultado_final.json"

echo "- Pronto! Para executar:"
echo "sudo $INSTALL_DIR/rede_tool.sh"
echo
echo "Arquivos de resultado serão salvos em:"
echo "  $INSTALL_DIR/resultado_final.txt"
echo "  $INSTALL_DIR/resultado_final.json"