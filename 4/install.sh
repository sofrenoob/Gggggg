#!/bin/bash

# Obtém o IP do servidor
echo "Obtendo o IP do servidor..."
SERVER_IP=$(hostname -I | awk '{print $1}')
if [ -z "$SERVER_IP" ]; then
    echo "Não foi possível obter o IP. Usando 'localhost' como fallback."
    SERVER_IP="localhost"
fi
echo "IP do servidor: $SERVER_IP"

# Atualiza o sistema e instala dependências básicas
echo "Atualizando o sistema e instalando dependências básicas..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential git curl wget nginx sslh badvpn sqlite3 libssl-dev libboost-all-dev python3 python3-pip openssh-server openvpn squid

# Instala dependências do Python para o bot Telegram
echo "Instalando dependências do Python para o bot Telegram..."
sudo pip3 install python-telegram-bot==20.6

# Cria diretórios e arquivos necessários
echo "Criando diretórios e arquivos de configuração..."
sudo mkdir -p /etc/ssl/certs
sudo mkdir -p ~/anyvpn_system

# Gera certificados SSL autoassinados
echo "Gerando certificados SSL..."
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/certs/server.key -out /etc/ssl/certs/server.crt -subj "/C=BR/ST=State/L=City/O=AnyVPN/CN=$SERVER_IP"

# Configura o Nginx
echo "Configurando o Nginx..."
sudo bash -c "cat > /etc/nginx/sites-available/anyvpn <<EOF
server {
    listen 80;
    listen 443 ssl;
    listen 8080 ssl;
    server_name $SERVER_IP;

    ssl_certificate /etc/ssl/certs/server.crt;
    ssl_certificate_key /etc/ssl/certs/server.key;

    location /direct {
        proxy_pass http://localhost:8443;
    }
    location /directnopayload {
        proxy_pass http://localhost:8443;
    }
    location /websocket {
        proxy_pass http://localhost:8080;
    }
    location /security {
        proxy_pass http://localhost:8443;
    }
    location /socks {
        proxy_pass http://localhost:7300; # Porta do Badvpn para SOCKS/UDP
    }
    location /ssldirect {
        proxy_pass https://localhost:8443;
    }
    location /sslpay {
        proxy_pass https://localhost:8443;
    }
}
EOF"
sudo ln -s /etc/nginx/sites-available/anyvpn /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# Configura o sslh
echo "Configurando o sslh..."
sudo bash -c 'cat > /etc/sslh.cfg <<EOF
port = 8444
ssl: 0.0.0.0:8444:tcp:localhost:8443
http: 0.0.0.0:8444:tcp:localhost:8080
ssh: 0.0.0.0:8444:tcp:localhost:22
openvpn: 0.0.0.0:8444:tcp:localhost:1194
proxy: 0.0.0.0:8444:tcp:localhost:3128
EOF'
sudo systemctl enable sslh
sudo systemctl restart sslh

# Inicia o Badvpn
echo "Iniciando o Badvpn..."
badvpn-udpgw --listen-addr 127.0.0.1 --listen-port 7300 &

# Baixa os arquivos do repositório
echo "Baixando server.cpp e bot_telegram.py do repositório..."
cd ~/anyvpn_system
wget https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/server.cpp
wget https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/bot_telegram.py

# Compila o servidor
echo "Compilando o servidor..."
g++ -o server server.cpp -lboost_system -lboost_thread -lsqlite3 -pthread -lcrypto -lssl

# Cria arquivos de controle
echo "Criando arquivos de controle..."
touch ~/anyvpn_system/bot_command.txt
touch ~/anyvpn_system/bot_response.txt
echo "desativado" > ~/anyvpn_system/bot_status.txt
touch ~/anyvpn_system/udp_history.db

# Define permissões
echo "Definindo permissões..."
sudo chmod +x ~/anyvpn_system/server
sudo chmod +x ~/anyvpn_system/bot_telegram.py
sudo chmod 644 /etc/ssl/certs/server.crt
sudo chmod 600 /etc/ssl/certs/server.key
sudo chmod 644 /etc/nginx/sites-available/anyvpn
sudo chmod 644 /etc/sslh.cfg
sudo chown -R $USER:$USER ~/anyvpn_system

# Inicia o servidor
echo "Iniciando o servidor..."
cd ~/anyvpn_system
./server &

echo "Instalação concluída! Acesse o bot Telegram com /menu após configurá-lo (opção 4.1 e 4.3)."