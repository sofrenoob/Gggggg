#!/bin/bash

# Atualização do sistema operacional
echo "Atualizando o sistema..."
apt update && apt upgrade -y

# Instalação de dependências básicas
echo "Instalando dependências básicas..."
apt install -y python3 python3-pip curl git unzip

# Instalação de bibliotecas Python necessárias
echo "Instalando bibliotecas Python necessárias..."
pip3 install requests curses typer

# Diretório de instalação
INSTALL_DIR="/opt/proxy_vpn_manager"
BIN_DIR="/usr/local/bin"
echo "Criando diretório de instalação em: $INSTALL_DIR"
mkdir -p $INSTALL_DIR

# Links para download das ferramentas
PROXY_PY_URL="https://github.com/abhinavsingh/proxy.py/archive/refs/heads/develop.zip"
GOPROXY_URL="https://github.com/snail007/goproxy/archive/refs/heads/master.zip"
MENU_SCRIPT_URL="https://raw.githubusercontent.com/sofrenoob/Gggggg/main/mm/mm/proxy_vpn_manager.py"

# Baixando e configurando proxy.py
echo "Baixando e configurando proxy.py..."
curl -L $PROXY_PY_URL -o $INSTALL_DIR/proxy.py.zip
unzip $INSTALL_DIR/proxy.py.zip -d $INSTALL_DIR
rm $INSTALL_DIR/proxy.py.zip

# Baixando e configurando goproxy
echo "Baixando e configurando goproxy..."
curl -L $GOPROXY_URL -o $INSTALL_DIR/goproxy.zip
unzip $INSTALL_DIR/goproxy.zip -d $INSTALL_DIR
rm $INSTALL_DIR/goproxy.zip

# Baixando o menu principal
echo "Baixando o menu principal..."
curl -L $MENU_SCRIPT_URL -o $INSTALL_DIR/proxy_vpn_manager.py
chmod +x $INSTALL_DIR/proxy_vpn_manager.py

# Configurando permissões
echo "Configurando permissões..."
chmod -R 755 $INSTALL_DIR
chown -R root:root $INSTALL_DIR

# Criando link simbólico para o menu principal
echo "Criando link simbólico para o menu principal no diretório binário..."
ln -sf $INSTALL_DIR/proxy_vpn_manager.py $BIN_DIR/proxy_vpn_manager

# Configuração final
echo "Instalação concluída com sucesso!"
echo "Execute 'proxy_vpn_manager' no terminal para iniciar o menu principal."