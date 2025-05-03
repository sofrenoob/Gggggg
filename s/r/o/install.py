#!/bin/bash
echo -e "\e[44m\e[97m       ALFA PROXY - INSTALADOR        \e[0m"
sleep 2

DEST="/opt/alfaproxy"
sudo mkdir -p $DEST/logs

# Instalar dependências
apt update && apt install -y python3 python3-pip screen openssl
pip3 install -r $DEST/requirements.txt
sudo apt update
sudo apt install -y python3 python3-pip openssl screen

# Gerar certificado SSL
openssl req -new -x509 -days 365 -nodes -out $DEST/cert.pem -keyout $DEST/key.pem -subj "/CN=AlfaProxy"

# Ativação inicial em background
screen -dmS alfaproxy python3 $DEST/proxy_server.py

# Instalando libs Python
pip3 install websocket-server

# Baixando arquivos do repositório
wget -O $DEST/proxy_server.py https://raw.githubusercontent.com/sofrenoob/Gggggg/main/sr/o/proxy_server.py
wget -O $DEST/payloads.txt https://raw.githubusercontent.com/sofrenoob/Gggggg/main/sr/o/payloads.txt
wget -O $DEST/cert.pem https://raw.githubusercontent.com/sofrenoob/Gggggg/main/sr/o/cert.pem
wget -O $DEST/key.pem https://raw.githubusercontent.com/sofrenoob/Gggggg/main/sr/o/key.pem
wget -O $DEST/menuproxy.sh https://raw.githubusercontent.com/sofrenoob/Gggggg/main/sr/o/menuproxy.sh
wget -O $DEST/config.txt https://raw.githubusercontent.com/sofrenoob/Gggggg/main/sr/o/config.txt
wget -O $DEST/requirements.txt https://raw.githubusercontent.com/sofrenoob/Gggggg/main/sr/o/requirements.txt

# Configuração padrão de porta
echo "80" > $DEST/config.txt

# Permissões
chmod +x $DEST/proxy_server.py
chmod 600 $DEST/*.pem
chmod +x $DEST/menuproxy.sh

# Criando alias de menu
echo 'alias menuproxy="screen -dmS alfa-proxy python3 /opt/alfaproxy/proxy_server.py && echo -e \"\e[44m\e[97m ALFA PROXY RODANDO \e[0m\""' >> ~/.bashrc
source ~/.bashrc

# Finalizando
echo -e "\e[42m\e[97m Instalação concluída. Digite 'menuproxy' para iniciar. \e[0m"
