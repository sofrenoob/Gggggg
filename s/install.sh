#!/bin/bash

# Atualizar o sistema e instalar dependências
echo "Atualizando o sistema e instalando dependências..."
sudo apt update && sudo apt upgrade -y

# Instalar Python 3, pip e pacotes necessários
echo "Instalando o Python 3 e pacotes necessários..."
sudo apt install python3 python3-pip python3-psutil -y

# Instalar ufw (se não estiver instalado)
echo "Instalando UFW (Firewall)"
sudo apt install ufw -y

# Configurar permissões para firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Ativar o firewall
echo "Ativando firewall..."
sudo ufw enable

# Dando permissão de execução ao script
chmod +x scripts/script.py

echo "Instalação completa!"
echo "Execute o script Python com o comando: python3 bash <(wget -qO- https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/"
