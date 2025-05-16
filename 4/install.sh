

CONFIG_FILE="/etc/myapp/config.json"
LOG_FILE="/var/log/myapp.log"

# Função para carregar a configuração
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        mkdir -p "$(dirname "$CONFIG_FILE")"
        echo '{"users":[], "proxy":{}, "firewall":{}, "routing":[], "badvpn":{}, "anyproxy":{}}' > "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE" # Restrito ao root
    fi
    config=$(cat "$CONFIG_FILE")
}

# Função para salvar a configuração
save_config() {
    echo "$config" | jq . > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE" # Restrito ao root
}

# Função para log de ações
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Função para instalar dependências
install_dependencies() {
    echo "Instalando dependências..."
    apt-get update || { echo "Falha ao atualizar pacotes"; exit 1; }

    # Instalar pacotes disponíveis nos repositórios padrão
    apt-get install -y jq iptables net-tools || { echo "Falha ao instalar dependências"; exit 1; }

    # Instalar websocat (se não estiver disponível nos repositórios)
    if ! command -v websocat &> /dev/null; then
        echo "Instalando websocat..."
        wget https://github.com/vi/websocat/releases/download/v1.10.0/websocat_linux64 -O /usr/local/bin/websocat
        chmod +x /usr/local/bin/websocat
    fi

    # Instalar BadVPN (se não estiver disponível nos repositórios)
    if ! command -v badvpn &> /dev/null; then
        echo "Instalando BadVPN..."
        apt-get install -y build-essential cmake git || { echo "Falha ao instalar dependências para BadVPN"; exit 1; }
        git clone https://github.com/ambrop72/badvpn.git /tmp/badvpn
        mkdir /tmp/badvpn/build
        cd /tmp/badvpn/build
        cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_TUN2SOCKS=1 -DBUILD_UDPGW=1
        make
        make install
        cd ~
        rm -rf /tmp/badvpn
    fi

    # Instalar AnyProxy (se não estiver disponível nos repositórios)
    if ! command -v anyproxy &> /dev/null; then
        echo "Instalando AnyProxy..."
        apt-get install -y npm || { echo "Falha ao instalar npm"; exit 1; }
        npm install -g anyproxy
    fi

    # Criar pasta de logs e configurar permissões
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE" # Leitura para todos, escrita apenas para root

    # Criar pasta de configurações
    mkdir -p "$(dirname "$CONFIG_FILE")"
    chmod 700 "$(dirname "$CONFIG_FILE")" # Apenas root pode acessar

    echo "Dependências instaladas e pastas configuradas com sucesso!"
    log "Dependências instaladas"
}

# Menu interativo
menu() {
    clear
    echo "Menu de Gerenciamento"
    echo "1. Gerenciar Usuários SSH"
    echo "2. Gerenciar Proxy WebSocket Reverso"
    echo "3. Monitorar Conexões"
    echo "4. Configurar Firewall"
    echo "5. Configurar BadVPN"
    echo "6. Configurar AnyProxy"
    echo "7. Instalar Dependências"
    echo "8. Sair"
    read -p "Escolha uma opção: " choice
    case $choice in
        1) manage_ssh_users ;;
        2) manage_websocket_proxy ;;
        3) monitor_connections ;;
        4) manage_firewall ;;
        5) configure_badvpn ;;
        6) configure_anyproxy ;;
        7) install_dependencies ;;
        8) exit 0 ;;
        *) echo "Opção inválida"; sleep 1; menu ;;
    esac
}

# Gerenciamento de Usuários SSH
manage_ssh_users() {
    echo "Gerenciamento de Usuários SSH"
    echo "1. Adicionar Usuário"
    echo "2. Remover Usuário"
    echo "3. Listar Usuários"
    echo "4. Ver Usuários Online"
    echo "5. Voltar"
    read -p "Escolha uma opção: " ssh_choice
    case $ssh_choice in
        1)
            read -p "Nome do usuário: " username
            read -p "Data de expiração (YYYY-MM-DD): " expiry_date
            config=$(echo "$config" | jq --arg user "$username" --arg date "$expiry_date" '.users += [{"username": $user, "expiry_date": $date}]')
            save_config
            useradd -m -s /bin/bash "$username"
            passwd "$username"
            log "Usuário SSH adicionado: $username"
            ;;
        2)
            read -p "Nome do usuário: " username
            config=$(echo "$config" | jq --arg user "$username" 'del(.users[] | select(.username == $user))')
            save_config
            userdel -r "$username"
            log "Usuário SSH removido: $username"
            ;;
        3)
            echo "Usuários SSH:"
            echo "$config" | jq -r '.users[] | "\(.username) (Expira: \(.expiry_date))"'
            ;;
        4)
            echo "Usuários Online:"
            who
            ;;
        5) menu ;;
        *) echo "Opção inválida"; sleep 1; manage_ssh_users ;;
    esac
    menu
}

# Gerenciamento de Proxy WebSocket Reverso
manage_websocket_proxy() {
    echo "Gerenciamento de Proxy WebSocket Reverso"
    echo "1. Iniciar Proxy"
    echo "2. Parar Proxy"
    echo "3. Escolher Porta"
    echo "4. Voltar"
    read -p "Escolha uma opção: " proxy_choice
    case $proxy_choice in
        1)
            port=$(echo "$config" | jq -r '.proxy.port')
            if [ -z "$port" ]; then
                read -p "Escolha a porta: " port
                config=$(echo "$config" | jq --argjson port "$port" '.proxy.port = $port')
                save_config
            fi
            websocat -s 0.0.0.0:$port &>> "$LOG_FILE" &
            log "Proxy WebSocket iniciado na porta $port"
            ;;
        2)
            pkill websocat
            log "Proxy WebSocket parado"
            ;;
        3)
            read -p "Escolha a porta: " port
            config=$(echo "$config" | jq --argjson port "$port" '.proxy.port = $port')
            save_config
            log "Porta do proxy WebSocket alterada para $port"
            ;;
        4) menu ;;
        *) echo "Opção inválida"; sleep 1; manage_websocket_proxy ;;
    esac
    menu
}

# Monitoramento de Conexões
monitor_connections() {
    echo "Monitoramento de Conexões"
    echo "1. Ver Conexões Ativas"
    echo "2. Ver Logs"
    echo "3. Voltar"
    read -p "Escolha uma opção: " monitor_choice
    case $monitor_choice in
        1)
            netstat -tuln
            ;;
        2)
            tail -n 20 "$LOG_FILE"
            ;;
        3) menu ;;
        *) echo "Opção inválida"; sleep 1; monitor_connections ;;
    esac
    menu
}

# Gerenciamento de Firewall
manage_firewall() {
    echo "Gerenciamento de Firewall"
    echo "1. Abrir Porta"
    echo "2. Fechar Porta"
    echo "3. Listar Regras"
    echo "4. Voltar"
    read -p "Escolha uma opção: " firewall_choice
    case $firewall_choice in
        1)
            read -p "Porta: " port
            iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
            log "Porta $port aberta no firewall"
            ;;
        2)
            read -p "Porta: " port
            iptables -D INPUT -p tcp --dport "$port" -j ACCEPT
            log "Porta $port fechada no firewall"
            ;;
        3)
            iptables -L -n -v
            ;;
        4) menu ;;
        *) echo "Opção inválida"; sleep 1; manage_firewall ;;
    esac
    menu
}

# Configuração de BadVPN
configure_badvpn() {
    echo "Configuração de BadVPN"
    echo "1. Iniciar BadVPN"
    echo "2. Parar BadVPN"
    echo "3. Voltar"
    read -p "Escolha uma opção: " badvpn_choice
    case $badvpn_choice in
        1)
            badvpn &>> "$LOG_FILE" &
            log "BadVPN iniciado"
            ;;
        2)
            pkill badvpn
            log "BadVPN parado"
            ;;
        3) menu ;;
        *) echo "Opção inválida"; sleep 1; configure_badvpn ;;
    esac
    menu
}

# Configuração de AnyProxy
configure_anyproxy() {
    echo "Configuração de AnyProxy"
    echo "1. Iniciar AnyProxy"
    echo "2. Parar AnyProxy"
    echo "3. Escolher Porta"
    echo "4. Voltar"
    read -p "Escolha uma opção: " anyproxy_choice
    case $anyproxy_choice in
        1)
            port=$(echo "$config" | jq -r '.anyproxy.port')
            if [ -z "$port" ]; then
                read -p "Escolha a porta: " port
                config=$(echo "$config" | jq --argjson port "$port" '.anyproxy.port = $port')
                save_config
            fi
            anyproxy --port "$port" &>> "$LOG_FILE" &
            log "AnyProxy iniciado na porta $port"
            ;;
        2)
            pkill anyproxy
            log "AnyProxy parado"
            ;;
        3)
            read -p "Escolha a porta: " port
            config=$(echo "$config" | jq --argjson port "$port" '.anyproxy.port = $port')
            save_config
            log "Porta do AnyProxy alterada para $port"
            ;;
        4) menu ;;
        *) echo "Opção inválida"; sleep 1; configure_anyproxy ;;
    esac
    menu
}

# Inicialização
if [ "$EUID" -ne 0 ]; then
    echo "Por favor, execute como root."
    exit 1
fi
load_config
menu
