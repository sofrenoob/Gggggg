#!/bin/bash

# Função para verificar erros
check_error() {
    if [ $? -ne 0 ]; then
        echo "Erro: $1"
        exit 1
    fi
}

# Função para limpar arquivos, serviços e pacotes instalados
clean_installation() {
    echo "Iniciando limpeza de arquivos, serviços e pacotes..."

    # Para serviços em execução
    echo "Parando serviços..."
    sudo systemctl stop nginx 2>/dev/null
    sudo systemctl stop sslh 2>/dev/null
    sudo systemctl stop badvpn-udpgw 2>/dev/null
    sudo pkill -f badvpn-udpgw 2>/dev/null
    sudo pkill -f server 2>/dev/null

    # Desativa serviços
    echo "Desativando serviços..."
    sudo systemctl disable nginx 2>/dev/null
    sudo systemctl disable sslh 2>/dev/null
    sudo systemctl disable badvpn-udpgw 2>/dev/null

    # Remove arquivos de configuração
    echo "Removendo arquivos de configuração..."
    [ -f /etc/nginx/sites-available/anyvpn ] && sudo rm /etc/nginx/sites-available/anyvpn
    [ -f /etc/nginx/sites-enabled/anyvpn ] && sudo rm /etc/nginx/sites-enabled/anyvpn
    [ -f /etc/sslh.cfg ] && sudo rm /etc/sslh.cfg
    [ -f /etc/ssl/certs/server.crt ] && sudo rm /etc/ssl/certs/server.crt
    [ -f /etc/ssl/certs/server.key ] && sudo rm /etc/ssl/certs/server.key
    [ -f /etc/systemd/system/badvpn-udpgw.service ] && sudo rm /etc/systemd/system/badvpn-udpgw.service

    # Remove diretórios e arquivos do projeto
    echo "Removendo diretórios e arquivos do projeto..."
    [ -d ~/anyvpn_system ] && rm -rf ~/anyvpn_system
    [ -d /tmp/badvpn ] && rm -rf /tmp/badvpn

    # Desinstala pacotes
    echo "Desinstalando pacotes..."
    sudo apt purge -y build-essential git curl wget nginx sqlite3 libssl-dev libboost-all-dev python3 python3-pip openssh-server openvpn squid cmake libnspr4-dev libnss3-dev
    sudo apt autoremove -y
    check_error "Falha ao desinstalar pacotes"

    # Remove dependências do Python
    echo "Removendo dependências do Python..."
    sudo pip3 uninstall -y python-telegram-bot

    # Remove badvpn instalado manualmente
    echo "Removendo badvpn compilado..."
    sudo rm -f /usr/bin/badvpn-udpgw /usr/bin/badvpn-tun2socks /usr/bin/badvpn-server

    # Recarrega configurações do systemd
    echo "Recarregando configurações do systemd..."
    sudo systemctl daemon-reload
    sudo systemctl reset-failed

    echo "Limpeza concluída!"
}

# Verifica se o argumento --clean foi passado
if [ "$1" == "--clean" ]; then
    clean_installation
    exit 0
fi

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
check_error "Falha ao atualizar o sistema"
sudo apt install -y build-essential git curl wget nginx sqlite3 libssl-dev libboost-all-dev python3 python3-pip openssh-server openvpn squid cmake libnspr4-dev libnss3-dev
check_error "Falha ao instalar dependências básicas"

# Remove pacotes desnecessários
echo "Removendo pacotes desnecessários..."
sudo apt autoremove -y

# Instala o badvpn a partir do código-fonte
echo "Instalando badvpn a partir do código-fonte..."
cd /tmp
# Remove o diretório badvpn existente, se houver
if [ -d badvpn ]; then
    echo "Removendo diretório badvpn existente..."
    rm -rf badvpn
    sleep 1  # Pequena pausa para garantir que a remoção seja concluída
fi
git clone https://github.com/ambrop72/badvpn.git
check_error "Falha ao clonar o repositório badvpn"
cd badvpn
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr
check_error "Falha ao configurar o badvpn"
make && sudo make install
check_error "Falha ao compilar/instalar o badvpn"
cd /tmp && rm -rf badvpn

# Instala dependências do Python para o bot Telegram
echo "Instalando dependências do Python para o bot Telegram..."
sudo pip3 install python-telegram-bot==20.6
check_error "Falha ao instalar python-telegram-bot"

# Cria diretórios e arquivos necessários
echo "Criando diretórios e arquivos de configuração..."
sudo mkdir -p /etc/ssl/certs
sudo mkdir -p ~/anyvpn_system
check_error "Falha ao criar diretórios"

# Gera certificados SSL autoassinados
echo "Gerando certificados SSL..."
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/certs/server.key -out /etc/ssl/certs/server.crt -subj "/C=BR/ST=State/L=City/O=AnyVPN/CN=$SERVER_IP"
check_error "Falha ao gerar certificados SSL"

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
check_error "Falha ao criar arquivo de configuração do Nginx"
sudo ln -s /etc/nginx/sites-available/anyvpn /etc/nginx/sites-enabled/
check_error "Falha ao criar link simbólico para Nginx"
sudo nginx -t
check_error "Configuração do Nginx inválida"
sudo systemctl restart nginx
check_error "Falha ao reiniciar o Nginx"

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
check_error "Falha ao criar arquivo de configuração do sslh"
sudo systemctl enable sslh
sudo systemctl restart sslh
check_error "Falha ao iniciar o sslh"

# Inicia o Badvpn
echo "Iniciando o badvpn-udpgw..."
sudo badvpn-udpgw --listen-addr 127.0.0.1 --listen-port 7300 &
check_error "Falha ao iniciar o badvpn-udpgw"

# Baixa os arquivos do repositório
echo "Baixando server.cpp e bot_telegram.py do repositório..."
cd ~/anyvpn_system
wget https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/server.cpp
check_error "Falha ao baixar server.cpp"
wget https://raw.githubusercontent.com/sofrenoob/Gggggg/main/4/bot_telegram.py
check_error "Falha ao baixar bot_telegram.py"

# Compila o servidor
echo "Compilando o servidor..."
g++ -o server server.cpp -lboost_system -lboost_thread -lsqlite3 -pthread -lcrypto -lssl
check_error "Falha ao compilar o servidor"

# Cria arquivos de controle
echo "Criando arquivos de controle..."
touch ~/anyvpn_system/bot_command.txt ~/anyvpn_system/bot_response.txt ~/anyvpn_system/udp_history.db
echo "desativado" > ~/anyvpn_system/bot_status.txt
check_error "Falha ao criar arquivos de controle"

# Define permissões
echo "Definindo permissões..."
[ -f ~/anyvpn_system/server ] && sudo chmod +x ~/anyvpn_system/server
[ -f ~/anyvpn_system/bot_telegram.py ] && sudo chmod +x ~/anyvpn_system/bot_telegram.py
[ -f /etc/ssl/certs/server.crt ] && sudo chmod 644 /etc/ssl/certs/server.crt
[ -f /etc/ssl/certs/server.key ] && sudo chmod 600 /etc/ssl/certs/server.key
[ -f /etc/nginx/sites-available/anyvpn ] && sudo chmod 644 /etc/nginx/sites-available/anyvpn
[ -f /etc/sslh.cfg ] && sudo chmod 644 /etc/sslh.cfg
sudo chown -R $USER:$USER ~/anyvpn_system
check_error "Falha ao definir permissões"

# Inicia o servidor
echo "Iniciando o servidor..."
cd ~/anyvpn_system
[ -f ./server ] && ./server &
check_error "Falha ao iniciar o servidor"

echo "Instalação concluída! Acesse o bot Telegram com /menu após configurá-lo (opção 4.1 e 4.3)."