#!/bin/bash

# AlfaMenager Install Script
# by @alfalemos 👾🥷

clear
echo -e "\e[1;36m[+] Instalando dependências e configurando ambiente...\e[0m"

# Atualizar sistema
apt update && apt upgrade -y

# Instalar dependências
apt install -y socat screen jq dnsmasq curl speedtest-cli python3 python3-pip zip unzip

# Instalar dependências Python
pip3 install flask

# Criar estrutura de diretórios
mkdir -p AlfaMenager/logs

# Baixar arquivos do projeto (links de exemplo — troque pelos do seu repo)
echo -e "\e[1;36m[+] Baixando arquivos do projeto...\e[0m"

cd AlfaMenager

wget -O install.sh https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/r/install.sh
wget -O menu.sh https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/r/menu.sh
wget -O proxy_listener.sh https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/r/proxy_listener.sh
wget -O dns_custom.sh https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/r/dns_custom.sh
wget -O memory_store.sh https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/r/memory_store.sh
wget -O monitor_real_time.sh https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/r/monitor_real_time.sh
wget -O alfa_api.py https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/r/alfa_api.py
wget -O start_tunnels.sh https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/r/start_tunnels.sh
wget -O README.md https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/r/README.md

# Criar arquivos padrão
echo "[]" > memory.json
touch logs/conexoes.log

# Dar permissões
chmod +x *.sh alfa_api.py

# Configurar DNS avançado
bash dns_custom.sh

# Iniciar serviços em screen
echo -e "\e[1;36m[+] Iniciando serviços em background...\e[0m"
screen -dmS proxy_listener bash proxy_listener.sh
screen -dmS monitor bash monitor_real_time.sh
screen -dmS alfa_api ./alfa_api.py

# Exibir IP externo
IP=$(curl -s ifconfig.me)
echo -e "\e[1;32m[✓] Instalação finalizada.\e[0m"
echo -e "\e[1;33m[+] IP Externo: $IP\e[0m"

# Iniciar menu
bash menu.sh
