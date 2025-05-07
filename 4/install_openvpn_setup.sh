#!/bin/bash

# Verifica se o usuário é root
if [[ $EUID -ne 0 ]]; then
   echo "Por favor, execute este script como root (use sudo)"
   exit 1
fi

echo "=== Iniciando o instalador ==="

# Atualizar pacotes do sistema
echo "Atualizando pacotes do sistema..."
apt update && apt upgrade -y

# Instalar Python3 e pip
echo "Instalando Python3 e pip..."
apt install -y python3 python3-pip

# Criar diretório para o programa
INSTALL_DIR="/opt/openvpn-setup"
echo "Criando diretório ${INSTALL_DIR}..."
mkdir -p $INSTALL_DIR

# Fazer download do script Python
echo "Baixando o script Python para ${INSTALL_DIR}..."
wget -O $INSTALL_DIR/openvpn_setup.py https://raw.githubusercontent.com/sofrenoob/Gggggg/refs/heads/main/4/openvpn_setup.py

# Verificar se o download foi bem-sucedido
if [[ ! -f $INSTALL_DIR/openvpn_setup.py ]]; then
    echo "Falha ao baixar o script. Verifique o link e tente novamente."
    exit 1
fi

# Tornar o script Python executável
echo "Tornando o script executável..."
chmod +x $INSTALL_DIR/openvpn_setup.py

# Criar um alias para facilitar a execução
echo "Criando um alias para facilitar a execução..."
BASHRC_FILE="/etc/bash.bashrc"
if ! grep -q "alias openvpn-setup" $BASHRC_FILE; then
    echo "alias openvpn-setup='python3 /opt/openvpn-setup/openvpn_setup.py'" >> $BASHRC_FILE
    echo "O alias 'openvpn-setup' foi adicionado ao sistema."
fi

# Atualizar o ambiente atual
source $BASHRC_FILE

echo "=== Instalação concluída! ==="
echo "Você pode executar o programa digitando: openvpn-setup"