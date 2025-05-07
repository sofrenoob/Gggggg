#!/bin/bash

# Configurações iniciais
SCRIPT_URL="https://raw.githubusercontent.com/sofrenoob/Gggggg/refs/heads/main/4/painel_supervisor.py"
SCRIPT_NAME="painel_supervisor.py"
INSTALL_DIR="/usr/local/bin"
PYTHON_PATH=$(command -v python3)

echo "Iniciando a instalação do Painel..."

# Função para verificar e liberar bloqueios do apt
check_and_remove_locks() {
    echo "Verificando bloqueios do gerenciador de pacotes..."
    LOCK_FILES=("/var/lib/dpkg/lock-frontend" "/var/lib/dpkg/lock" "/var/cache/apt/archives/lock")
    for LOCK_FILE in "${LOCK_FILES[@]}"; do
        if [ -f "$LOCK_FILE" ]; then
            echo "Removendo bloqueio em $LOCK_FILE..."
            sudo rm -f "$LOCK_FILE"
        fi
    done

    # Verificar processos bloqueadores e terminá-los
    echo "Verificando processos bloqueadores..."
    BLOCKING_PROCESSES=$(ps aux | grep -iE "apt|dpkg" | grep -v grep | awk '{print $2}')
    if [ -n "$BLOCKING_PROCESSES" ]; then
        echo "Encerrando processos bloqueadores..."
        echo "$BLOCKING_PROCESSES" | xargs sudo kill -9
    fi

    # Reconfigurando pacotes pendentes
    echo "Reconfigurando pacotes..."
    sudo dpkg --configure -a
}

# Verificar bloqueios e removê-los antes de prosseguir
check_and_remove_locks

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

# Garantir que o pip está atualizado
echo "Atualizando o pip..."
pip3 install --upgrade pip

# Instalar dependências necessárias
echo "Instalando dependências do Python..."
pip3 install psutil rich --quiet

# Verificar se as dependências foram instaladas corretamente
echo "Verificando a instalação das dependências..."
if ! python3 -c "import psutil, rich" &> /dev/null; then
    echo "Erro ao instalar as dependências do Python. Tentando novamente..."
    pip3 install psutil rich --force-reinstall --quiet
    if ! python3 -c "import psutil, rich" &> /dev/null; then
        echo "As bibliotecas psutil e rich não foram instaladas corretamente. Verifique sua instalação do Python e tente novamente."
        exit 1
    fi
fi

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
echo "Adicionando permissões de execução ao script..."
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