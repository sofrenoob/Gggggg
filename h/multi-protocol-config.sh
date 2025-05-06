#!/bin/bash

# Script MultiProtocolos para Servidores de Proxy - Ubuntu/Debian
# Autor: Seu Nome
# Data: $(date +"%Y-%m-%d")
# Versão: 2.0

# Variáveis globais
PROXY_PORT=3128
WEBSOCKET_PORT=8080
SLOWDNS_DOMAIN="example.com"
SLOWDNS_SERVER_IP="192.168.0.1"
OPENVPN_NETWORK="10.8.0.0"
OPENVPN_NETMASK="255.255.255.0"

# Função para verificar o sucesso de um comando
verificar_erro() {
    if [ $? -ne 0 ]; then
        echo "[ERRO] $1"
        exit 1
    fi
}

# Função para instalar dependências básicas
instalar_dependencias() {
    echo "[INFO] Atualizando lista de pacotes..."
    apt-get update -y && apt-get upgrade -y
    verificar_erro "Falha ao atualizar pacotes."

    echo "[INFO] Instalando pacotes necessários..."
    apt-get install -y curl wget net-tools dnsutils openvpn badvpn socat screen haproxy iodine cmake git iptables-persistent build-essential stunnel4 squid nodejs npm dante-server
    verificar_erro "Falha ao instalar dependências básicas."
}

# Função para configurar certificados autoassinados com entradas personalizadas
gerar_certificado() {
    local CERT_PATH=$1
    echo "[INFO] Gerando certificado autoassinado..."
    read -p "Digite o nome do domínio (exemplo.com): " DOMAIN
    read -p "Digite o e-mail do administrador: " EMAIL
    openssl req -new -x509 -days 365 -nodes -out "$CERT_PATH" -keyout "$CERT_PATH" <<EOF
US
California
San Francisco
My Organization
My Unit
$DOMAIN
$EMAIL
EOF
    verificar_erro "Falha ao gerar certificado."
    chmod 600 "$CERT_PATH"
}

# Função para persistir regras de firewall
salvar_regras_firewall() {
    echo "[INFO] Salvando regras de firewall..."
    iptables-save > /etc/iptables/rules.v4
    verificar_erro "Falha ao salvar regras de firewall."
}

# Menu principal
menu_principal() {
    while true; do
        clear
        echo "============================================="
        echo "      Configuração de Servidor MultiProtocolos"
        echo "============================================="
        echo "Escolha os protocolos que deseja configurar:"
        echo "1) Proxy (Squid)"
        echo "2) WebSocket"
        echo "3) Security (TLS)"
        echo "4) ProxySocks (Dante)"
        echo "5) OpenVPN"
        echo "6) OpenTunnel"
        echo "7) OpenProxy (HAProxy)"
        echo "8) SSL Tunnel"
        echo "9) SSL Proxy"
        echo "10) BadVPN (UDP Forwarder)"
        echo "11) UDP Histeria"
        echo "12) DNS"
        echo "13) SlowDNS"
        echo "0) Sair"
        echo "============================================="
        read -rp "Digite a opção desejada: " opcao

        case $opcao in
            1) menu_proxy ;;
            2) menu_websocket ;;
            3) menu_security ;;
            4) menu_proxysocks ;;
            5) menu_openvpn ;;
            6) configurar_opentunnel ;;
            7) configurar_openproxy ;;
            8) configurar_ssl_tunnel ;;
            9) menu_ssl_proxy ;;
            10) configurar_badvpn ;;
            11) configurar_udp_histeria ;;
            12) menu_dns ;;
            13) configurar_slowdns ;;
            0) echo "[INFO] Saindo..."; exit 0 ;;
            *) echo "[ERRO] Opção inválida! Tente novamente."; sleep 2 ;;
        esac
    done
}

# Submenus e funções de configuração de cada protocolo
menu_proxy() {
    while true; do
        echo ""
        echo "======= MENU DE CONFIGURAÇÃO DO PROXY ======="
        echo "1. Configurar Proxy"
        echo "2. Exibir portas ativas"
        echo "3. Alterar porta principal"
        echo "4. Abrir nova porta"
        echo "5. Fechar porta"
        echo "6. Voltar ao menu principal"
        echo "============================================="
        read -rp "Escolha uma opção: " opcao

        case $opcao in
            1) configurar_proxy ;;
            2) exibir_portas_ativas ;;
            3) alterar_porta ;;
            4) abrir_porta ;;
            5) fechar_porta ;;
            6) break ;;
            *) echo "[ERRO] Opção inválida! Tente novamente."; sleep 2 ;;
        esac
    done
}

menu_websocket() {
    while true; do
        echo ""
        echo "======= MENU DE CONFIGURAÇÃO DO WEBSOCKET ======="
        echo "1. Configurar WebSocket"
        echo "2. Alterar porta principal do WebSocket"
        echo "3. Exibir porta configurada"
        echo "4. Voltar ao menu principal"
        echo "==============================================="
        read -rp "Escolha uma opção: " opcao

        case $opcao in
            1) configurar_websocket ;;
            2) alterar_porta_websocket ;;
            3) exibir_porta_websocket ;;
            4) break ;;
            *) echo "[ERRO] Opção inválida! Tente novamente."; sleep 2 ;;
        esac
    done
}

menu_security() {
    while true; do
        echo ""
        echo "======= MENU DE CONFIGURAÇÃO DO SECURITY (TLS) ======="
        echo "1. Configurar Security (TLS)"
        echo "2. Exibir status do serviço TLS"
        echo "3. Reiniciar serviço TLS"
        echo "4. Voltar ao menu principal"
        echo "======================================================"
        read -rp "Escolha uma opção: " opcao

        case $opcao in
            1) configurar_security ;;
            2) systemctl status stunnel4 --no-pager ;;
            3) systemctl restart stunnel4; echo "[INFO] TLS reiniciado com sucesso!" ;;
            4) break ;;
            *) echo "[ERRO] Opção inválida! Tente novamente."; sleep 2 ;;
        esac
    done
}

menu_proxysocks() {
    while true; do
        echo ""
        echo "======= MENU DE CONFIGURAÇÃO DO PROXYSOCKS ======="
        echo "1. Configurar ProxySocks (Dante Server)"
        echo "2. Exibir status do ProxySocks"
        echo "3. Reiniciar ProxySocks"
        echo "4. Voltar ao menu principal"
        echo "==============================================="
        read -rp "Escolha uma opção: " opcao

        case $opcao in
            1) configurar_proxysocks ;;
            2) systemctl status danted --no-pager ;;
            3) systemctl restart danted; echo "[INFO] ProxySocks reiniciado com sucesso!" ;;
            4) break ;;
            *) echo "[ERRO] Opção inválida! Tente novamente."; sleep 2 ;;
        esac
    done
}

menu_openvpn() {
    while true; do
        echo ""
        echo "======= MENU DE CONFIGURAÇÃO DO OPENVPN ======="
        echo "1. Configurar OpenVPN"
        echo "2. Exibir status do OpenVPN"
        echo "3. Reiniciar OpenVPN"
        echo "4. Voltar ao menu principal"
        echo "==============================================="
        read -rp "Escolha uma opção: " opcao

        case $opcao in
            1) configurar_openvpn ;;
            2) systemctl status openvpn@server --no-pager ;;
            3) systemctl restart openvpn@server; echo "[INFO] OpenVPN reiniciado com sucesso!" ;;
            4) break ;;
            *) echo "[ERRO] Opção inválida! Tente novamente."; sleep 2 ;;
        esac
    done
}

menu_ssl_proxy() {
    while true; do
        echo ""
        echo "======= MENU DE CONFIGURAÇÃO DO SSL PROXY ======="
        echo "1. Configurar SSL Proxy"
        echo "2. Exibir status do SSL Proxy"
        echo "3. Reiniciar SSL Proxy"
        echo "4. Voltar ao menu principal"
        echo "==============================================="
        read -rp "Escolha uma opção: " opcao

        case $opcao in
            1) configurar_ssl_proxy ;;
            2) systemctl status ssl-proxy --no-pager ;;
            3) systemctl restart ssl-proxy; echo "[INFO] SSL Proxy reiniciado com sucesso!" ;;
            4) break ;;
            *) echo "[ERRO] Opção inválida! Tente novamente."; sleep 2 ;;
        esac
    done
}

menu_dns() {
    while true; do
        echo ""
        echo "======= MENU DE CONFIGURAÇÃO DO DNS ======="
        echo "1. Configurar DNS"
        echo "2. Verificar status do serviço DNS"
        echo "3. Reiniciar serviço DNS"
        echo "4. Voltar ao menu principal"
        echo "=========================================="
        read -rp "Escolha uma opção: " opcao

        case $opcao in
            1) configurar_dns ;;
            2) systemctl status bind9 --no-pager ;;
            3) systemctl restart bind9; echo "[INFO] DNS reiniciado com sucesso!" ;;
            4) break ;;
            *) echo "[ERRO] Opção inválida! Tente novamente."; sleep 2 ;;
        esac
    done
}

# Fluxo principal para iniciar o script
instalar_dependencias
menu_principal
}

# Função para configurar cada protocolo
configurar_proxy() {
    echo "[INFO] Configurando Proxy..."

    # Instalar o Squid
    echo "[INFO] Instalando Squid..."
    apt-get update -y
    apt-get install -y squid

    # Configurar o arquivo squid.conf
    echo "[INFO] Configurando squid.conf..."
    cat >/etc/squid/squid.conf <<EOL
# Configuração básica do Squid Proxy
http_port 3128

# ACL para permitir acesso local
acl localnet src 192.168.0.0/16
acl localnet src 172.16.0.0/12
acl localnet src 10.0.0.0/8
acl localnet src fc00::/7
acl localnet src fe80::/10

# Permitir acesso para redes locais
http_access allow localnet
http_access allow localhost

# Bloquear todo o resto
http_access deny all

# Configurações de log
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log
EOL

    # Ajustar permissões e reiniciar o Squid
    echo "[INFO] Reiniciando o serviço Squid..."
    systemctl restart squid
    systemctl enable squid

    # Verificar status do Squid
    echo "[INFO] Verificando status do Proxy..."
    systemctl status squid --no-pager

    echo "[INFO] Proxy configurado com sucesso!"
}

# Função para exibir as portas configuradas no Squid
exibir_portas_ativas() {
    echo "[INFO] Exibindo portas ativas no Squid..."
    grep "^http_port" /etc/squid/squid.conf
}

# Função para alterar a porta principal do proxy
alterar_porta() {
    echo "[INFO] Alterando a porta principal do proxy..."
    read -p "Digite a nova porta para o proxy: " nova_porta
    if [[ -z "$nova_porta" ]]; then
        echo "[ERRO] Porta inválida! Operação cancelada."
        return
    fi
    sed -i "s/^http_port .*/http_port $nova_porta/" /etc/squid/squid.conf
    echo "[INFO] Porta principal alterada para $nova_porta."
    systemctl restart squid
}

# Função para abrir uma nova porta adicional
abrir_porta() {
    echo "[INFO] Abrindo uma nova porta para o proxy..."
    read -p "Digite a porta que deseja adicionar: " nova_porta
    if [[ -z "$nova_porta" ]]; then
        echo "[ERRO] Porta inválida! Operação cancelada."
        return
    fi
    if grep -q "^http_port $nova_porta" /etc/squid/squid.conf; then
        echo "[INFO] A porta $nova_porta já está configurada."
    else
        echo "http_port $nova_porta" >> /etc/squid/squid.conf
        echo "[INFO] Porta $nova_porta adicionada com sucesso."
        systemctl restart squid
    fi
}

# Função para fechar uma porta existente
fechar_porta() {
    echo "[INFO] Fechando uma porta configurada no proxy..."
    read -p "Digite a porta que deseja remover: " porta_remover
    if [[ -z "$porta_remover" ]]; then
        echo "[ERRO] Porta inválida! Operação cancelada."
        return
    fi
    if grep -q "^http_port $porta_remover" /etc/squid/squid.conf; then
        sed -i "/^http_port $porta_remover/d" /etc/squid/squid.conf
        echo "[INFO] Porta $porta_remover removida com sucesso."
        systemctl restart squid
    else
        echo "[INFO] A porta $porta_remover não está configurada."
    fi
}

configurar_websocket() {
    echo "[INFO] Configurando WebSocket..."

    # Instalar Node.js e npm
    echo "[INFO] Instalando Node.js e npm..."
    apt-get update -y
    apt-get install -y nodejs npm

    # Criar diretório para o projeto WebSocket
    echo "[INFO] Criando diretório para o servidor WebSocket..."
    mkdir -p /opt/websocket
    cd /opt/websocket

    # Inicializar um projeto Node.js
    echo "[INFO] Inicializando o projeto Node.js..."
    npm init -y

    # Instalar o pacote 'ws' para WebSocket
    echo "[INFO] Instalando o pacote 'ws' para WebSocket..."
    npm install ws

    # Criar o servidor WebSocket
    echo "[INFO] Criando o servidor WebSocket..."
    cat >server.js <<EOL
const WebSocket = require('ws');

// Porta padrão para o servidor WebSocket
const PORT = process.env.WEBSOCKET_PORT || 8080;

// Criando o servidor WebSocket
const wss = new WebSocket.Server({ port: PORT });

console.log(\`Servidor WebSocket rodando na porta \${PORT}\`);

// Evento de conexão
wss.on('connection', (ws) => {
    console.log('Cliente conectado');
    
    // Mensagem recebida do cliente
    ws.on('message', (message) => {
        console.log('Mensagem recebida:', message);
        ws.send('Mensagem recebida: ' + message);
    });

    // Cliente desconectado
    ws.on('close', () => {
        console.log('Cliente desconectado');
    });
});
EOL

    # Criar um serviço systemd para o servidor WebSocket
    echo "[INFO] Criando o serviço systemd para o WebSocket..."
    cat >/etc/systemd/system/websocket.service <<EOL
[Unit]
Description=Servidor WebSocket
After=network.target

[Service]
ExecStart=/usr/bin/node /opt/websocket/server.js
Restart=always
User=nobody
Group=nogroup
Environment=PATH=/usr/bin:/usr/local/bin
Environment=NODE_ENV=production
Environment=WEBSOCKET_PORT=8080
WorkingDirectory=/opt/websocket

[Install]
WantedBy=multi-user.target
EOL

    # Habilitar e iniciar o serviço WebSocket
    echo "[INFO] Habilitando e iniciando o serviço WebSocket..."
    systemctl daemon-reload
    systemctl enable websocket
    systemctl start websocket

    echo "[INFO] WebSocket configurado com sucesso!"
}

alterar_porta_websocket() {
    echo "[INFO] Alterando a porta principal do WebSocket..."
    read -p "Digite a nova porta para o WebSocket: " nova_porta
    if [[ -z "$nova_porta" ]]; then
        echo "[ERRO] Porta inválida! Operação cancelada."
        return
    fi

    # Alterar a porta no arquivo de serviço
    sed -i "s/Environment=WEBSOCKET_PORT=.*/Environment=WEBSOCKET_PORT=$nova_porta/" /etc/systemd/system/websocket.service
    echo "[INFO] Porta principal alterada para $nova_porta."

    # Reiniciar o serviço WebSocket
    systemctl daemon-reload
    systemctl restart websocket
}

exibir_porta_websocket() {
    echo "[INFO] Exibindo a porta configurada para o WebSocket..."
    porta=$(grep "Environment=WEBSOCKET_PORT" /etc/systemd/system/websocket.service | cut -d '=' -f 2)
    echo "Porta atual do WebSocket: $porta"
}

configurar_security() {
    echo "[INFO] Configurando Security (TLS)..."

    # Instalar o stunnel
    echo "[INFO] Instalando stunnel4..."
    apt-get update -y
    apt-get install -y stunnel4

    # Habilitar o stunnel no sistema
    echo "[INFO] Habilitando stunnel no sistema..."
    sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4

    # Criar certificado autoassinado
    echo "[INFO] Gerando certificado autoassinado para TLS..."
    openssl req -new -x509 -days 365 -nodes -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem <<EOF
US
California
San Francisco
My Organization
My Unit
localhost
admin@localhost
EOF

    # Ajustar permissões do certificado
    chmod 600 /etc/stunnel/stunnel.pem

    # Criar arquivo de configuração do stunnel
    echo "[INFO] Configurando stunnel..."
    cat > /etc/stunnel/stunnel.conf <<EOL
# Configuração do stunnel para TLS

# Ativar o modo daemon
foreground = no

# Arquivo de log
output = /var/log/stunnel4/stunnel.log

# Serviço TLS de exemplo: Redireciona conexões seguras para um servidor backend
[https]
accept = 443
connect = 127.0.0.1:8080
cert = /etc/stunnel/stunnel.pem
EOL

    # Reiniciar o stunnel para aplicar configurações
    echo "[INFO] Reiniciando o serviço stunnel..."
    systemctl restart stunnel4
    systemctl enable stunnel4

    # Verificar status do serviço
    echo "[INFO] Verificando o status do serviço TLS..."
    systemctl status stunnel4 --no-pager

    echo "[INFO] TLS configurado com sucesso!"
}

configurar_proxysocks() {
    echo "[INFO] Configurando ProxySocks..."

    # Instalar o Dante Server
    echo "[INFO] Instalando Dante Server..."
    apt-get update -y
    apt-get install -y dante-server

    # Criar arquivo de configuração para o Dante
    echo "[INFO] Configurando danted.conf..."
    cat >/etc/danted.conf <<EOL
# Configuração básica do Dante Server (SOCKS5)

logoutput: syslog
internal: 0.0.0.0 port = 1080
external: eth0
method: username none
user.privileged: root
user.notprivileged: nobody
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
}
EOL

    # Habilitar e iniciar o serviço Dante
    echo "[INFO] Habilitando e iniciando o serviço Dante..."
    systemctl restart danted
    systemctl enable danted

    # Verificar status do serviço
    echo "[INFO] Verificando o status do ProxySocks..."
    systemctl status danted --no-pager

    echo "[INFO] ProxySocks configurado com sucesso!"
}

configurar_openvpn() {
    echo "[INFO] Configurando OpenVPN..."

    # Instalar o OpenVPN
    echo "[INFO] Instalando OpenVPN..."
    apt-get update -y
    apt-get install -y openvpn easy-rsa

    # Configurar diretório para Easy-RSA
    echo "[INFO] Configurando Easy-RSA..."
    make-cadir /etc/openvpn/easy-rsa
    cd /etc/openvpn/easy-rsa || exit

    # Configurar variáveis para certificados
    echo "[INFO] Configurando variáveis para certificados..."
    cat > vars <<EOL
set_var EASYRSA_REQ_COUNTRY    "US"
set_var EASYRSA_REQ_PROVINCE   "California"
set_var EASYRSA_REQ_CITY       "San Francisco"
set_var EASYRSA_REQ_ORG        "My Organization"
set_var EASYRSA_REQ_EMAIL      "admin@localhost"
set_var EASYRSA_REQ_OU         "My Organizational Unit"
EOL

    # Gerar Certificado de Autoridade (CA)
    echo "[INFO] Gerando Certificado de Autoridade (CA)..."
    ./easyrsa init-pki
    ./easyrsa build-ca nopass

    # Gerar certificado e chave do servidor
    echo "[INFO] Gerando certificado e chave do servidor..."
    ./easyrsa gen-req server nopass
    ./easyrsa sign-req server server

    # Gerar Diffie-Hellman para segurança adicional
    echo "[INFO] Gerando parâmetros Diffie-Hellman..."
    ./easyrsa gen-dh

    # Configurar o servidor OpenVPN
    echo "[INFO] Configurando servidor OpenVPN..."
    cat > /etc/openvpn/server.conf <<EOL
port 1194
proto udp
dev tun
ca /etc/openvpn/easy-rsa/pki/ca.crt
cert /etc/openvpn/easy-rsa/pki/issued/server.crt
key /etc/openvpn/easy-rsa/pki/private/server.key
dh /etc/openvpn/easy-rsa/pki/dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /etc/openvpn/ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-CBC
persist-key
persist-tun
status /var/log/openvpn-status.log
log-append /var/log/openvpn.log
verb 3
EOL

    # Habilitar encaminhamento de IP
    echo "[INFO] Habilitando encaminhamento de IP..."
    echo 1 > /proc/sys/net/ipv4/ip_forward
    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    sysctl -p

    # Configurar regras de firewall
    echo "[INFO] Configurando regras de firewall..."
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
    iptables-save > /etc/iptables/rules.v4

    # Habilitar e iniciar o serviço OpenVPN
    echo "[INFO] Habilitando e iniciando OpenVPN..."
    systemctl enable openvpn@server
    systemctl start openvpn@server

    # Verificar status do serviço OpenVPN
    echo "[INFO] Verificando o status do OpenVPN..."
    systemctl status openvpn@server --no-pager

    echo "[INFO] OpenVPN configurado com sucesso!"
}

configurar_opentunnel() {
    echo "[INFO] Configurando OpenTunnel..."
    
    # Instalar dependências necessárias
    echo "[INFO] Instalando dependências para OpenTunnel..."
    apt-get install -y wget tar curl

    # Baixar o binário do OpenTunnel Server
    echo "[INFO] Baixando OpenTunnel Server..."
    wget -qO opentunnel-server.tar.gz https://example.com/path-to-opentunnel/server.tar.gz  # Atualize o link correto
    tar -xz