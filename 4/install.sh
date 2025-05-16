

# Cores para o terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sem cor

# Função para exibir o menu
show_menu() {
    clear
    echo -e "${GREEN}===== MENU PRINCIPAL =====${NC}"
    echo -e "${BLUE}1. Instalar Ferramentas${NC}"
    echo -e "${BLUE}2. Configurar V2Ray${NC}"
    echo -e "${BLUE}3. Configurar Shadowsocks${NC}"
    echo -e "${BLUE}4. Configurar WireGuard${NC}"
    echo -e "${BLUE}5. Configurar OpenVPN${NC}"
    echo -e "${BLUE}6. Configurar BadVPN${NC}"
    echo -e "${BLUE}7. Configurar Domain Fronting${NC}"
    echo -e "${BLUE}8. Configurar Criptografia Pós-Quântica${NC}"
    echo -e "${BLUE}9. Configurar Rede Mesh${NC}"
    echo -e "${BLUE}10. Gerenciar Portas${NC}"
    echo -e "${BLUE}11. Gerenciar Usuários SSH${NC}"
    echo -e "${BLUE}12. Monitoramento em Tempo Real${NC}"
    echo -e "${BLUE}13. Sair${NC}"
    echo -e "${GREEN}==========================${NC}"
}

# Função para instalar ferramentas
install_tools() {
    echo -e "${YELLOW}Instalando dependências...${NC}"
    sudo apt update
    sudo apt install -y curl wget git ufw shadowsocks-libev v2ray wireguard openvpn certbot haproxy prometheus grafana elasticsearch logstash kibana build-essential cmake libssl-dev

    echo -e "${YELLOW}Instalando BadVPN...${NC}"
    git clone https://github.com/ambrop72/badvpn.git
    cd badvpn
    mkdir build
    cd build
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_TUN2SOCKS=1 -DBUILD_UDPGW=1
    make
    sudo make install
    cd ../..

    echo -e "${YELLOW}Configurando firewall...${NC}"
    sudo ufw allow 22
    sudo ufw allow 80
    sudo ufw allow 443
    sudo ufw allow 8080
    sudo ufw allow 7300
    sudo ufw enable

    echo -e "${GREEN}Ferramentas instaladas e firewall configurado!${NC}"
}

# Função para configurar V2Ray
configure_v2ray() {
    echo -e "${YELLOW}Configurando V2Ray...${NC}"
    bash <(curl -sL https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

    echo -e "${GREEN}V2Ray configurado com sucesso!${NC}"
}

# Função para configurar Shadowsocks
configure_shadowsocks() {
    echo -e "${YELLOW}Configurando Shadowsocks...${NC}"
    read -p "Digite a senha para Shadowsocks: " password
    read -p "Digite a porta para Shadowsocks (padrão: 8388): " port
    port=${port:-8388}

    cat <<EOF | sudo tee /etc/shadowsocks-libev/config.json
{
    "server":"0.0.0.0",
    "server_port":$port,
    "password":"$password",
    "method":"aes-256-gcm"
}
EOF

    sudo systemctl restart shadowsocks-libev
    echo -e "${GREEN}Shadowsocks configurado com sucesso!${NC}"
}

# Função para configurar WireGuard
configure_wireguard() {
    echo -e "${YELLOW}Configurando WireGuard...${NC}"
    sudo apt install -y wireguard
    wg genkey | sudo tee /etc/wireguard/private.key
    sudo cat /etc/wireguard/private.key | wg pubkey | sudo tee /etc/wireguard/public.key

    echo -e "${GREEN}WireGuard configurado com sucesso!${NC}"
}

# Função para configurar OpenVPN
configure_openvpn() {
    echo -e "${YELLOW}Configurando OpenVPN...${NC}"
    wget https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
    chmod +x openvpn-install.sh
    sudo ./openvpn-install.sh

    echo -e "${GREEN}OpenVPN configurado com sucesso!${NC}"
}

# Função para configurar BadVPN
configure_badvpn() {
    echo -e "${YELLOW}Configurando BadVPN...${NC}"
    read -p "Digite a porta para BadVPN (padrão: 7300): " port
    port=${port:-7300}

    sudo badvpn-udpgw --listen-addr 0.0.0.0:$port &
    echo -e "${GREEN}BadVPN configurado com sucesso!${NC}"
}

# Função para configurar Domain Fronting
configure_domain_fronting() {
    echo -e "${YELLOW}Configurando Domain Fronting...${NC}"
    read -p "Digite o domínio fronting (ex: google.com): " domain
    cat <<EOF | sudo tee /etc/v2ray/config.json
{
    "inbounds": [
        {
            "port": 443,
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "seu-uuid-aqui",
                        "alterId": 64
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "/caminho-secreto"
                },
                "security": "tls",
                "tlsSettings": {
                    "serverName": "$domain"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        }
    ]
}
EOF

    sudo systemctl restart v2ray
    echo -e "${GREEN}Domain Fronting configurado com sucesso!${NC}"
}

# Função para configurar Criptografia Pós-Quântica
configure_post_quantum() {
    echo -e "${YELLOW}Configurando Criptografia Pós-Quântica...${NC}"
    sudo apt install -y liboqs-dev
    git clone https://github.com/open-quantum-safe/openssl.git
    cd openssl
    ./Configure
    make
    sudo make install

    echo -e "${GREEN}Criptografia Pós-Quântica configurada com sucesso!${NC}"
}

# Função para configurar Rede Mesh
configure_mesh_network() {
    echo -e "${YELLOW}Configurando Rede Mesh...${NC}"
    sudo apt install -y yggdrasil
    yggdrasil -genconf > /etc/yggdrasil.conf
    sudo systemctl enable yggdrasil
    sudo systemctl start yggdrasil

    echo -e "${GREEN}Rede Mesh configurada com sucesso!${NC}"
}

# Função para gerenciar portas
manage_ports() {
    echo -e "${YELLOW}Gerenciando Portas...${NC}"
    echo -e "${BLUE}Portas atualmente abertas:${NC}"
    sudo ufw status

    read -p "Deseja abrir uma nova porta? (s/n): " choice
    if [[ $choice == "s" ]]; then
        read -p "Digite o número da porta: " port
        sudo ufw allow $port
        echo -e "${GREEN}Porta $port aberta!${NC}"
    fi
}

# Função para gerenciar usuários SSH
manage_ssh_users() {
    echo -e "${YELLOW}Gerenciando Usuários SSH...${NC}"
    echo -e "${BLUE}1. Adicionar Usuário${NC}"
    echo -e "${BLUE}2. Remover Usuário${NC}"
    echo -e "${BLUE}3. Voltar${NC}"
    read -p "Escolha uma opção: " option

    case $option in
        1)
            read -p "Digite o nome do usuário: " username
            read -p "Digite a senha do usuário: " password
            sudo useradd -m -s /bin/bash $username
            echo "$username:$password" | sudo chpasswd
            echo -e "${GREEN}Usuário $username adicionado!${NC}"
            ;;
        2)
            read -p "Digite o nome do usuário: " username
            sudo userdel -r $username
            echo -e "${RED}Usuário $username removido!${NC}"
            ;;
        3)
            return
            ;;
        *)
            echo -e "${RED}Opção inválida!${NC}"
            ;;
    esac
}

# Função para monitoramento em tempo real
configure_monitoring() {
    echo -e "${YELLOW}Configurando Monitoramento em Tempo Real...${NC}"
    sudo systemctl enable prometheus
    sudo systemctl start prometheus
    sudo systemctl enable grafana-server
    sudo systemctl start grafana-server

    echo -e "${GREEN}Monitoramento configurado com sucesso!${NC}"
}

# Loop do menu
while true; do
    show_menu
    read -p "Escolha uma opção: " choice

    case $choice in
        1) install_tools ;;
        2) configure_v2ray ;;
        3) configure_shadowsocks ;;
        4) configure_wireguard ;;
        5) configure_openvpn ;;
        6) configure_badvpn ;;
        7) configure_domain_fronting ;;
        8) configure_post_quantum ;;
        9) configure_mesh_network ;;
        10) manage_ports ;;
        11) manage_ssh_users ;;
        12) configure_monitoring ;;
        13) break ;;
        *) echo -e "${RED}Opção inválida!${NC}" ;;
    esac

    read -p "Pressione Enter para continuar..."
done

echo -e "${GREEN}Programa finalizado.${NC}"
