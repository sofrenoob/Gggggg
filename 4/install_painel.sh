#!/bin/bash

# Configurações iniciais
SCRIPT_URL="https://raw.githubusercontent.com/sofrenoob/Gggggg/refs/heads/main/4/painel_supervisor.py"
SCRIPT_NAME="painel_supervisor.py"
INSTALL_DIR="/usr/local/bin"
PYTHON_PATH=$(command -v python3)

echo "Iniciando a instalação do Painel..."

# Verificar se o Python está instalado
if [ -z "$PYTHON_PATH" ]; then
    echo "Python3 não está instalado. Instalando Python3..."
    sudo apt-get update && sudo apt-get install -y python3
fi

# Verificar se o pip está instalado
PIP_PATH=$(command -v pip3)
if [ -z "$PIP_PATH" ]; then
    echo "pip3 não está instalado. Instalando pip3..."
    sudo apt-get install -y python3-pip
fi

# Instalar dependências necessárias
echo "Instalando dependências do Python..."
pip3 install psutil rich

# Baixar o arquivo do script
echo "Baixando o script do painel..."
curl -o "$SCRIPT_NAME" "$SCRIPT_URL"

# Verificar se o download foi bem-sucedido
if [ $? -ne 0 ]; then
    echo "Erro ao baixar o script. Verifique o link fornecido."
    exit 1
fi

# Mover o script para o diretório de instalação
echo "Movendo o script para $INSTALL_DIR..."
sudo mv "$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"

# Garantir permissões de execução
echo "Adicionando permissões de execução..."
sudo chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# Criar um alias para execução fácil
echo "Criando um alias para facilitar a execução..."
if ! grep -q "alias painel='sudo python3 $INSTALL_DIR/$SCRIPT_NAME'" ~/.bashrc; then
    echo "alias painel='sudo python3 $INSTALL_DIR/$SCRIPT_NAME'" >> ~/.bashrc
    source ~/.bashrc
fi

# Finalizar
echo "Instalação concluída!"
echo "Você pode executar o painel com o comando: painel"