#!/bin/bash

# Verificar se o script está rodando como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute como root."
  exit 1
fi

# Diretório de destino
DEST_DIR="/usr/bin"

# Lista de arquivos e seus links de download
declare -A FILES
FILES["meuscript1"]="https://exemplo.com/meuscript1.sh"
FILES["meuscript2"]="https://exemplo.com/meuscript2.sh"

# Baixar os arquivos e mover para o diretório de destino
for FILE in "${!FILES[@]}"; do
  echo "Baixando $FILE..."
  wget -q "${FILES[$FILE]}" -O "$DEST_DIR/$FILE"
  chmod +x "$DEST_DIR/$FILE"
done

# Criar um atalho ARQUIVO apontando para um dos scripts (ex: meuscript1)
ln -sf "$DEST_DIR/meuscript1" "$DEST_DIR/ARQUIVO"

echo "Instalação concluída. Você pode executar com o comando: ARQUIVO"
