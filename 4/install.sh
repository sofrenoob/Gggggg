#!/bin/bash

# Função para centralizar texto
center_text() {
    local text="$1"
    local width="$2"
    local len=${#text}
    local padding=$(( (width - len) / 2 ))
    printf "%${padding}s%s%${padding}s" "" "$text" ""
    if [ $(( (width - len) % 2 )) -ne 0 ]; then
        printf " "
    fi
}

# Função para configurar persistência de firewall
setup_firewall_persistence() {
    if [[ -f /etc/debian_version ]]; then
        local persistent_pkg="netfilter-persistent"
        if [[ $(grep -oP '(?<=^DISTRIB_RELEASE=).+' /etc/lsb-release 2>/dev/null) == "18.04" || $(grep -oP '(?<=^VERSION_ID=").+' /etc/os-release) =~ ^9 ]]; then
            persistent_pkg="iptables-persistent"
        fi
        if ! dpkg -l | grep -q "$persistent_pkg"; then
            echo "Instalando $persistent_pkg para persistência de regras..."
            sudo apt update
            sudo apt install "$persistent_pkg" -y
        fi
        sudo iptables-save | sudo tee /etc/iptables/rules.v4
        sudo ip6tables-save | sudo tee /etc/iptables/rules.v6
    elif [[ -f /etc/redhat-release ]]; then
        if ! rpm -q firewalld >/dev/null; then
            echo "Instalando firewalld para persistência de regras..."
            sudo yum install firewalld -y
            sudo systemctl enable firewalld
            sudo systemctl start firewalld
        fi
        sudo firewall-cmd --permanent --add-port="$1"/tcp
        sudo firewall-cmd --permanent --add-port="$1"/udp
        sudo firewall-cmd --reload
    else
        echo "Sistema não suportado para persistência de firewall."
    fi
}

# Função para testar conectividade
test_connectivity() {
    local endpoint="$1"
    local max_latency=500
    local response_time=$(curl -s -o /dev/null -w "%{time_total}" "https://$endpoint" 2>/dev/null)
    if [[ -z "$response_time" ]]; then
        return 1
    fi
    local latency=$(echo "$response_time * 1000" | bc -l | cut -d. -f1)
    if [[ "$latency" -gt "$max_latency" ]]; then
        return 1
    fi
    return 0
}

# Função para o sistema inteligente de conexões
smart_connect() {
    clear
    echo "Sistema Inteligente de Conexões"
    echo "1) Ativar Sistema"
    echo "2) Desativar Sistema"
    echo "3) Configurar Servidores"
    echo "4) Verificar Status"
    echo "5) Gerar Configurações Padrão"
    echo "6) Configurar Notificações Telegram"
    echo "7) Voltar"
    read -p "> " opt
    case $opt in
        1) start_smart_connect ;;
        2) stop_smart_connect ;;
        3) configure_smart_connect ;;
        4) check_smart_status ;;
        5) generate_default_configs ;;
        6) configure_telegram_notifications ;;
        7) return ;;
        *) echo "Opção inválida."; echo "Pressione Enter para continuar..."; read ;;
    esac
}

# Função para iniciar o sistema inteligente
start_smart_connect() {
    clear
    echo "Iniciando Sistema Inteligente..."
    if [[ -f /tmp/smart_connect.pid ]]; then
        echo "Sistema já está em execução."
        echo "Pressione Enter para continuar..."
        read
        return
    fi
    smart_connect_loop &
    local pid=$!
    echo "$pid" > /tmp/smart_connect.pid
    echo "Sistema iniciado (PID: $pid)."
    echo "Pressione Enter para continuar..."
    read
}

# Função para parar o sistema inteligente
stop_smart_connect() {
    clear
    echo "Parando Sistema Inteligente..."
    if [[ -f /tmp/smart_connect.pid ]]; then
        local pid=$(cat /tmp/smart_connect.pid)
        kill "$pid" 2>/dev/null
        rm -f /tmp/smart_connect.pid
        echo "Sistema parado."
    else
        echo "Sistema não está em execução."
    fi
    echo "Pressione Enter para continuar..."
    read
}

# Função para enviar notificações ao Telegram
send_telegram_notification() {
    local message="$1"
    if [[ ! -f /etc/conexão/telegram.conf ]]; then
        return
    fi
    source /etc/conexão/telegram.conf
    if [[ "$TELEGRAM_ENABLED" != "true" || -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
        return
    fi
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$message" >/dev/null
}

# Função para configurar notificações Telegram
configure_telegram_notifications() {
    clear
    echo "Configurar Notificações Telegram"
    echo "1) Ativar Notificações"
    echo "2) Desativar Notificações"
    echo "3) Cadastrar Token e Chat ID"
    echo "4) Voltar"
    read -p "> " opt
    case $opt in
        1)
            echo "TELEGRAM_ENABLED=true" | sudo tee -a /etc/conexão/telegram.conf
            echo "Notificações Telegram ativadas."
            ;;
        2)
            echo "Tools" | sudo tee /etc/conexão/telegram.conf
            echo "Notificações Telegram desativadas."
            ;;
        3)
            clear
            echo "Digite o Token do Bot Telegram (ex.: 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11):"
            read -p "> " bot_token
            echo "Digite o Chat ID (ex.: -1001234567890 ou 123456789):"
            read -p "> " chat_id
            cat <<EOF | sudo tee /etc/conexão/telegram.conf
TELEGRAM_BOT_TOKEN="$bot_token"
TELEGRAM_CHAT_ID="$chat_id"
TELEGRAM_ENABLED=true
EOF
            echo "Configuração do Telegram salva em /etc/conexão/telegram.conf."
            ;;
        4)
            return
            ;;
        *)
            echo "Opção inválida."
            ;;
    esac
    echo "Pressione Enter para continuar..."
    read
}

# Função para configurar servidores
configure_smart_connect() {
    clear
    echo "Configurando Servidores para Sistema Inteligente..."
    echo "Formato: protocolo:serviço:porta:config[:remote_server[:payload]]. Exemplo:"
    echo "v2ray:v2ray:10086:/usr/local/etc/v2ray/config.json::path=/custom_ws"
    echo "Digite 'fim' para terminar:"
    mkdir -p /etc/conexão
    > /etc/conexão/smart.conf
    while true; do
        read -p "> " line
        if [[ "$line" == "fim" ]]; then
            break
        fi
        echo "$line" >> /etc/conexão/smart.conf
    done
    echo "Configuração salva em /etc/conexão/smart.conf."
    echo "Pressione Enter para continuar..."
    read
}

# Função para verificar status do sistema inteligente
check_smart_status() {
    clear
    echo "Status do Sistema Inteligente..."
    if [[ -f /tmp/smart_connect.pid ]]; then
        local pid=$(cat /tmp/smart_connect.pid)
        if ps -p "$pid" >/dev/null; then
            echo "Sistema em execução (PID: $pid)."
            if [[ -f /tmp/smart_connect.log ]]; then
                echo "Últimas entradas do log:"
                tail -n 10 /tmp/smart_connect.log
            fi
        else
            echo "Sistema não está em execução (PID inválido)."
            rm -f /tmp/smart_connect.pid
        fi
    else
        echo "Sistema não está em execução."
    fi
    echo "Pressione Enter para continuar..."
    read
}

# Função principal do loop do sistema inteligente
smart_connect_loop() {
    local endpoints=("google.com" "8.8.8.8" "cloudflare.com")
    local log_file="/tmp/smart_connect.log"
    echo "Iniciando loop do Sistema Inteligente..." > "$log_file"
    while true; do
        if [[ ! -f /etc/conexão/smart.conf ]]; then
            echo "Erro: Configuração não encontrada em /etc/conexão/smart.conf" >> "$log_file"
            send_telegram_notification "Erro: Configuração não encontrada em /etc/conexão/smart.conf"
            sleep 10
            continue
        fi
        local protocols=()
        local services=()
        local ports=()
        local configs=()
        local remote_servers=()
        local payloads=()
        while IFS=':' read -r proto svc port cfg remote payload; do
            protocols+=("$proto")
            services+=("$svc")
            ports+=("$port")
            configs+=("$cfg")
            remote_servers+=("${remote:-}")
            payloads+=("${payload:-}")
        done < /etc/conexão/smart.conf

        local connected=false
        for endpoint in "${endpoints[@]}"; do
            if test_connectivity "$endpoint"; then
                connected=true
                break
            fi
        done
        if ! $connected; then
            echo "$(date): Conexão instável ou caiu. Testando protocolos..." >> "$log_file"
            send_telegram_notification "Conexão instável ou caiu. Testando protocolos..."
            local best_proto=""
            local best_service=""
            local best_port=""
            local best_config=""
            local best_remote=""
            local best_payload=""
            local best_latency=9999
            for i in "${!protocols[@]}"; do
                local proto="${protocols[$i]}"
                local svc="${services[$i]}"
                local port="${ports[$i]}"
                local cfg="${configs[$i]}"
                local remote="${remote_servers[$i]}"
                local payload="${payloads[$i]}"
                echo "$(date): Testando $proto ($svc, porta $port${remote:+, remoto $remote}${payload:+, payload $payload})..." >> "$log_file"
                case "$proto" in
                    shadowsocks)
                        if [[ -n "$remote" ]]; then
                            sudo sed -i "s/\"server\": \".*\"/\"server\": \"$remote\"/" "$cfg" 2>/dev/null
                        fi
                        if [[ -n "$payload" ]]; then
                            sudo sed -i "s/\"plugin_opts\": \".*\"/\"plugin_opts\": \"$payload\"/" "$cfg" 2>/dev/null
                        fi
                        sudo systemctl start "$svc" 2>/dev/null
                        ;;
                    wireguard)
                        if [[ -n "$remote" ]]; then
                            sudo sed -i "s/Endpoint = .*/Endpoint = $remote:$port/" "$cfg" 2>/dev/null
                        fi
                        sudo wg-quick up "${svc##*@}" 2>/dev/null
                        ;;
                    v2ray|xray)
                        if [[ -n "$remote" ]]; then
                            sudo sed -i "s/\"address\": \".*\"/\"address\": \"$remote\"/" "$cfg" 2>/dev/null
                        fi
                        if [[ -n "$payload" && "$payload" =~ ^path= ]]; then
                            local path=${payload#path=}
                            sudo sed -i "s/\"path\": \".*\"/\"path\": \"$path\"/" "$cfg" 2>/dev/null
                        fi
                        sudo systemctl start "$svc" 2>/dev/null
                        ;;
                    openvpn)
                        if [[ -n "$remote" ]]; then
                            sudo sed -i "s/remote .*/remote $remote $port/" "$cfg" 2>/dev/null
                        fi
                        sudo openvpn --config "$cfg" --daemon 2>/dev/null
                        ;;
                esac
                sleep 2
                for endpoint in "${endpoints[@]}"; do
                    if test_connectivity "$endpoint"; then
                        local latency=$(curl -s -o /dev/null -w "%{time_total}" "https://$endpoint" 2>/dev/null)
                        latency=$(echo "$latency * 1000" | bc -l | cut -d. -f1)
                        latency=${latency:-9999}
                        if [[ "$latency" -lt "$best_latency" ]]; then
                            best_proto="$proto"
                            best_service="$svc"
                            best_port="$port"
                            best_config="$cfg"
                            best_remote="$remote"
                            best_payload="$payload"
                            best_latency="$latency"
                        fi
                        break
                    fi
                done
                case "$proto" in
                    shadowsocks|v2ray|xray)
                        sudo systemctl stop "$svc" 2>/dev/null
                        ;;
                    wireguard)
                        sudo wg-quick down "${svc##*@}" 2>/dev/null
                        ;;
                    openvpn)
                        sudo pkill -f "openvpn.*$cfg" 2>/dev/null
                        ;;
                esac
            done
            if [[ -n "$best_proto" ]]; then
                echo "$(date): Conectando com $best_proto ($best_service, porta $best_port${best_remote:+, remoto $best_remote}${best_payload:+, payload $best_payload}, latência $best_latency ms)..." >> "$log_file"
                send_telegram_notification "Conectado com $best_proto ($best_service, porta $best_port${best_remote:+, remoto $best_remote}${best_payload:+, payload $best_payload}, latência $best_latency ms)"
                case "$best_proto" in
                    shadowsocks)
                        if [[ -n "$best_remote" ]]; then
                            sudo sed -i "s/\"server\": \".*\"/\"server\": \"$best_remote\"/" "$best_config" 2>/dev/null
                        fi
                        if [[ -n "$best_payload" ]]; then
                            sudo sed -i "s/\"plugin_opts\": \".*\"/\"plugin_opts\": \"$best_payload\"/" "$best_config" 2>/dev/null
                        fi
                        sudo systemctl start "$best_service"
                        ;;
                    wireguard)
                        if [[ -n "$best_remote" ]]; then
                            sudo sed -i "s/Endpoint = .*/Endpoint = $best_remote:$best_port/" "$best_config" 2>/dev/null
                        fi
                        sudo wg-quick up "${best_service##*@}"
                        ;;
                    v2ray|xray)
                        if [[ -n "$best_remote" ]]; then
                            sudo sed -i "s/\"address\": \".*\"/\"address\": \"$best_remote\"/" "$best_config" 2>/dev/null
                        fi
                        if [[ -n "$best_payload" && "$best_payload" =~ ^path= ]]; then
                            local path=${best_payload#path=}
                            sudo sed -i "s/\"path\": \".*\"/\"path\": \"$path\"/" "$best_config" 2>/dev/null
                        fi
                        sudo systemctl start "$best_service"
                        ;;
                    openvpn)
                        if [[ -n "$best_remote" ]]; then
                            sudo sed -i "s/remote .*/remote $best_remote $best_port/" "$best_config" 2>/dev/null
                        fi
                        sudo openvpn --config "$best_config" --daemon
                        ;;
                esac
            else
                echo "$(date): Nenhum protocolo funcional encontrado." >> "$log_file"
                send_telegram_notification "Nenhum protocolo funcional encontrado."
            fi
        fi
        sleep 10
    done
}

# Função para remover regras de firewall
remove_ports() {
    local service="$1"
    local default_port="$2"
    clear
    echo "Digite a porta para remover (padrão: $default_port):"
    read -p "> " port
    port=${port:-$default_port}
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        echo "Porta inválida."
        echo "Pressione Enter para continuar..."
        read
        return
    fi
    sudo iptables -D INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null
    sudo iptables -D INPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null
    if [[ -f /etc/debian_version ]]; then
        sudo iptables-save | sudo tee /etc/iptables/rules.v4
    elif [[ -f /etc/redhat-release ]]; then
        sudo firewall-cmd --permanent --remove-port="$port"/tcp 2>/dev/null
        sudo firewall-cmd --permanent --remove-port="$port"/udp 2>/dev/null
        sudo firewall-cmd --reload
    fi
    echo "Porta $port removida para $service."
    echo "Pressione Enter para continuar..."
    read
}

# Função para listar portas abertas
list_ports() {
    local service="$1"
    local default_port="$2"
    clear
    echo "Listando portas abertas para $service (padrão: $default_port)..."
    if [[ -f /etc/debian_version ]]; then
        echo "=== Portas TCP ==="
        sudo iptables -L INPUT -v -n | grep -E "dpt:$default_port" || echo "Nenhuma porta TCP encontrada."
        echo "=== Portas UDP ==="
        sudo iptables -L INPUT -v -n | grep -E "dpt:$default_port.*udp" || echo "Nenhuma porta UDP encontrada."
    elif [[ -f /etc/redhat-release ]]; then
        echo "=== Portas abertas (TCP/UDP) ==="
        sudo firewall-cmd --list-ports | grep "$default_port" || echo "Nenhuma porta encontrada."
    else
        echo "Sistema não suportado."
    fi
    echo "Pressione Enter para continuar..."
    read
}

# Função para desenhar o menu principal
draw_main_menu() {
    clear
    local title=$(figlet -f small -w 50 "Gerenciar Conexões" | sed 's/^/  /')
    local width=50

    echo -e "\e[96m╔════════════════════════════════════════════════════╗\e[0m"
    while IFS= read -r line; do
        echo -e "\e[96m║\e[95m$(center_text "$line" $width)\e[96m║\e[0m"
    done <<< "$title"
    echo -e "\e[96m╠════════════════════════════════════════════════════╣\e[0m"
    echo -e "\e[96m║\e[93m  \e[1m1\e[0m\e[93m Proxy             \e[1m8\e[0m\e[93m XRay              \e[96m║\e[0m"
    echo -e "\e[96m║\e[93m  \e[1m2\e[0m\e[93m Proxy WebSocket   \e[1m9\e[0m\e[93m SlowDNS           \e[96m║\e[0m"
    echo -e "\e[96m║\e[93m  \e[1m3\e[0m\e[93m SSH Proxy         \e[1m10\e[0m\e[93m BadVPN           \e[96m║\e[0m"
    echo -e "\e[96m║\e[93m  \e[1m4\e[0m\e[93m SSL Tunnel        \e[1m11\e[0m\e[93m UDPGW            \e[96m║\e[0m"
    echo -e "\e[96m║\e[93m  \e[1m5\e[0m\e[93m SSL Proxy         \e[1m12\e[0m\e[93m Shadowsocks      \e[96m║\e[0m"
    echo -e "\e[96m║\e[93m  \e[1m6\e[0m\e[93m OpenVPN           \e[1m13\e[0m\e[93m WireGuard        \e[96m║\e[0m"
    echo -e "\e[96m║\e[93m  \e[1m7\e[0m\e[93m V2Ray             \e[1m14\e[0m\e[93m Sistema Inteligente \e[96m║\e[0m"
    echo -e "\e[96m║\e[93m  \e[1m15\e[0m\e[93m Sair             \e[96m║\e[0m"
    echo -e "\e[96m╩════════════════════════════════════════════════════╩\e[0m"
    echo -e "\e[96m[\e[95mOPÇÃO\e[96m]: \e[0m\c"
}

# Função para desenhar submenu
draw_submenu() {
    local service_name="$1"
    clear
    local title=$(figlet -f small -w 50 "$service_name" | sed 's/^/  /')
    local width=50

    echo -e "\e[96m╔════════════════════════════════════════════════════╗\e[0m"
    while IFS= read -r line; do
        echo -e "\e[96m║\e[95m$(center_text "$line" $width)\e[96m║\e[0m"
    done <<< "$title"
    echo -e "\e[96m╠════════════════════════════════════════════════════╣\e[0m"
    echo -e "\e[96m║\e[92m$(center_text "Gerenciamento de $service_name" $width)\e[96m║\e[0m"
    echo -e "\e[96m╠════════════════════════════════════════════════════╣\e[0m"
    echo -e "\e[96m║\e[93m  \e[1m1\e[0m\e[93m Verificar Status  \e[1m6\e[0m\e[93m Remover Portas    \e[96m║\e[0m"
    echo -e "\e[96m║\e[93m  \e[1m2\e[0m\e[93m Iniciar/Parar     \e[1m7\e[0m\e[93m Configurar        \e[96m║\e[0m"
    echo -e "\e[96m║\e[93m  \e[1m3\e[0m\e[93m Instalar          \e[1m8\e[0m\e[93m Desinstalar       \e[96m║\e[0m"
    echo -e "\e[96m║\e[93m  \e[1m4\e[0m\e[93m Abrir Portas      \e[1m9\e[0m\e[93m Alterar Portas    \e[96m║\e[0m"
    echo -e "\e[96m║\e[93m  \e[1m5\e[0m\e[93m Listar Portas Abertas \e[1m10\e[0m\e[93m Voltar        \e[96m║\e[0m"
    echo -e "\e[96m╩════════════════════════════════════════════════════╩\e[0m"
    echo -e "\e[96m[\e[95mOPÇÃO\e[96m]: \e[0m\c"
}

# Função genérica para verificar status
check_status() {
    local service="$1"
    local cmd="$2"
    clear
    echo "Verificando status de $service..."
    if command -v "$cmd" >/dev/null 2>&1 || systemctl is-active "$service" >/dev/null 2>&1; then
        systemctl status "$service" --no-pager | head -n 10
    else
        echo "$service não está instalado."
    fi
    echo "Pressione Enter para continuar..."
    read
}

# Função genérica para iniciar/parar
start_stop() {
    local service="$1"
    clear
    echo "1) Iniciar $service"
    echo "2) Parar $service"
    read -p "> " opt
    case $opt in
        1)
            sudo systemctl start "$service" 2>/dev/null || echo "Erro ao iniciar $service."
            echo "$service iniciado."
            ;;
        2)
            sudo systemctl stop "$service" 2>/dev/null || echo "Erro ao parar $service."
            echo "$service parado."
            ;;
        *)
            echo "Opção inválida."
            ;;
    esac
    echo "Pressione Enter para continuar..."
    read
}

# Função genérica para abrir portas
open_ports() {
    local service="$1"
    local default_port="$2"
    clear
    echo "Digite a porta para abrir (padrão: $default_port):"
    read -p "> " port
    port=${port:-$default_port}
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        echo "Porta inválida."
        echo "Pressione Enter para continuar..."
        read
        return
    fi
    sudo iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
    sudo iptables -A INPUT -p udp --dport "$port" -j ACCEPT
    setup_firewall_persistence "$port"
    echo "Porta $port aberta para $service e salva persistentemente."
    echo "Pressione Enter para continuar..."
    read
}

# Função genérica para alterar portas
change_ports() {
    local service="$1"
    local config_file="$2"
    local default_port="$3"
    clear
    echo "Digite a nova porta para $service (padrão: $default_port):"
    read -p "> " port
    port=${port:-$default_port}
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        echo "Porta inválida."
        echo "Pressione Enter para continuar..."
        read
        return
    fi
    if [[ -f "$config_file" ]]; then
        sudo sed -i "s/port [0-9]\+/port $port/" "$config_file" 2>/dev/null || \
        sudo sed -i "s/server_port\": [0-9]\+/server_port\": $port/" "$config_file" 2>/dev/null || \
        sudo sed -i "s/ListenPort = [0-9]\+/ListenPort = $port/" "$config_file" 2>/dev/null || \
        sudo sed -i "s/http_port [0-9]\+/http_port $port/" "$config_file" 2>/dev/null || \
        sudo sed -i "s/accept = [0-9]\+/accept = $port/" "$config_file" 2>/dev/null
        sudo systemctl restart "$service" 2>/dev/null
        echo "Porta alterada para $port em $config_file."
    else
        echo "Arquivo de configuração $config_file não encontrado."
    fi
    echo "Pressione Enter para continuar..."
    read
}

# Função para instalar Proxy (ex.: Squid)
install_proxy() {
    clear
    echo "Instalando Proxy (Squid)..."
    if [[ -f /etc/debian_version ]]; then
        sudo apt update
        sudo apt install squid -y
    elif [[ -f /etc/redhat-release ]]; then
        sudo yum install squid -y
    else
        echo "Sistema não suportado."
    fi
    echo "Proxy instalado. Pressione Enter para continuar..."
    read
}

# Função para configurar Proxy
configure_proxy() {
    clear
    echo "Configurando Proxy (Squid)..."
    echo "Digite a porta do proxy (padrão: 3128):"
    read -p "> " port
    port=${port:-3128}
    sudo sed -i "s/http_port [0-9]\+/http_port $port/" /etc/squid/squid.conf 2>/dev/null
    sudo systemctl restart squid
    echo "Proxy configurado na porta $port."
    echo "Pressione Enter para continuar..."
    read
}

# Função para desinstalar Proxy
uninstall_proxy() {
    clear
    echo "Desinstalando Proxy (Squid)..."
    sudo systemctl stop squid
    if [[ -f /etc/debian_version ]]; then
        sudo apt remove --purge squid -y
    elif [[ -f /etc/redhat-release ]]; then
        sudo yum remove squid -y
    fi
    echo "Proxy desinstalado. Pressione Enter para continuar..."
    read
}

# Função para instalar Proxy WebSocket (ex.: wstunnel)
install_websocket() {
    clear
    echo "Instalando Proxy WebSocket (wstunnel)..."
    if ! command -v wstunnel >/dev/null; then
        wget https://github.com/erebe/wstunnel/releases/latest/download/wstunnel-linux-x86_64 -O /usr/local/bin/wstunnel
        chmod +x /usr/local/bin/wstunnel
    fi
    echo "WebSocket instalado. Pressione Enter para continuar..."
    read
}

# Função para configurar WebSocket
configure_websocket() {
    clear
    echo "Configurando Proxy WebSocket..."
    echo "Digite a porta WebSocket (padrão: 8080):"
    read -p "> " port
    port=${port:-8080}
    echo "Configuração manual necessária. Execute: wstunnel --server ws://0.0.0.0:$port"
    echo "Pressione Enter para continuar..."
    read
}

# Função para desinstalar WebSocket
uninstall_websocket() {
    clear
    echo "Desinstalando Proxy WebSocket..."
    sudo rm -f /usr/local/bin/wstunnel
    echo "WebSocket desinstalado. Pressione Enter para continuar..."
    read
}

# Função para instalar SSH Proxy (ex.: sshuttle)
install_ssh_proxy() {
    clear
    echo "Instalando SSH Proxy (sshuttle)..."
    if [[ -f /etc/debian_version ]]; then
        sudo apt update
        sudo apt install sshuttle -y
    elif [[ -f /etc/redhat-release ]]; then
        sudo yum install sshuttle -y
    fi
    echo "SSH Proxy instalado. Pressione Enter para continuar..."
    read
}

# Função para configurar SSH Proxy
configure_ssh_proxy() {
    clear
    echo "Configurando SSH Proxy..."
    echo "Digite o servidor SSH (ex.: user@host):"
    read -p "> " ssh_server
    echo "Execute manualmente: sshuttle -r $ssh_server 0/0"
    echo "Pressione Enter para continuar..."
    read
}

# Função para desinstalar SSH Proxy
uninstall_ssh_proxy() {
    clear
    echo "Desinstalando SSH Proxy..."
    if [[ -f /etc/debian_version ]]; then
        sudo apt remove --purge sshuttle -y
    elif [[ -f /etc/redhat-release ]]; then
        sudo yum remove sshuttle -y
    fi
    echo "SSH Proxy desinstalado. Pressione Enter para continuar..."
    read
}

# Função para instalar SSL Tunnel (ex.: stunnel)
install_ssl_tunnel() {
    clear
    echo "Instalando SSL Tunnel (stunnel)..."
    if [[ -f /etc/debian_version ]]; then
        sudo apt update
        sudo apt install stunnel4 -y
    elif [[ -f /etc/redhat-release ]]; then
        sudo yum install stunnel -y
    fi
    echo "SSL Tunnel instalado. Pressione Enter para continuar..."
    read
}

# Função para configurar SSL Tunnel
configure_ssl_tunnel() {
    clear
    echo "Configurando SSL Tunnel..."
    echo "Digite a porta de escuta (padrão: 443):"
    read -p "> " port
    port=${port:-443}
    cat <<EOF | sudo tee /etc/stunnel/stunnel.conf
[ssl]
accept = $port
connect = 127.0.0.1:80
EOF
    sudo systemctl restart stunnel4
    echo "SSL Tunnel configurado na porta $port."
    echo "Pressione Enter para continuar..."
    read
}

# Função para desinstalar SSL Tunnel
uninstall_ssl_tunnel() {
    clear
    echo "Desinstalando SSL Tunnel..."
    sudo systemctl stop stunnel4
    if [[ -f /etc/debian_version ]]; then
        sudo apt remove --purge stunnel4 -y
    elif [[ -f /etc/redhat-release ]]; then
        sudo yum remove stunnel -y
    fi
    echo "SSL Tunnel desinstalado. Pressione Enter para continuar..."
    read
}

# Função para instalar OpenVPN
install_openvpn() {
    clear
    echo "Instalando OpenVPN..."
    if [[ -f /etc/debian_version ]]; then
        sudo apt update
        sudo apt install openvpn -y
    elif [[ -f /etc/redhat-release ]]; then
        sudo yum install openvpn -y
    fi
    echo "OpenVPN instalado. Pressione Enter para continuar..."
    read
}

# Função para configurar OpenVPN
configure_openvpn() {
    clear
    echo "Configurando OpenVPN..."
    echo "Digite o caminho do arquivo .ovpn:"
    read -p "> " ovpn_file
    if [[ -f "$ovpn_file" ]]; then
        sudo openvpn --config "$ovpn_file" --daemon
        echo "OpenVPN iniciado com $ovpn_file."
    else
        echo "Arquivo .ovpn não encontrado."
    fi
    echo "Pressione Enter para continuar..."
    read
}

# Função para desinstalar OpenVPN
uninstall_openvpn() {
    clear
    echo "Desinstalando OpenVPN..."
    sudo systemctl stop openvpn
    if [[ -f /etc/debian_version ]]; then
        sudo apt remove --purge openvpn -y
    elif [[ -f /etc/redhat-release ]]; then
        sudo yum remove openvpn -y
    fi
    echo "OpenVPN desinstalado. Pressione Enter para continuar..."
    read
}

# Função para instalar V2Ray
install_v2ray() {
    clear
    echo "Instalando V2Ray..."
    bash <(curl -L https://github.com/v2fly/v2ray-core/releases/latest/download/install-release.sh)
    echo "V2Ray instalado. Pressione Enter para continuar..."
    read
}

# Função para gerar configurações padrão
generate_default_configs() {
    clear
    echo "Gerando Configurações Padrão para Serviços..."
    mkdir -p /etc/conexão
    > /etc/conexão/smart.conf
    local log_file="/tmp/smart_connect.log"

    # Shadowsocks
    if command -v ss-server >/dev/null; then
        local ss_port=8388
        local ss_password=$(openssl rand -base64 12)
        cat <<EOF | sudo tee /etc/shadowsocks-libev/config.json
{
    "server": "0.0.0.0",
    "server_port": $ss_port,
    "local_port": 1080,
    "password": "$ss_password",
    "timeout": 60,
    "method": "aes-256-gcm"
}
EOF
        sudo systemctl restart shadowsocks-libev 2>/dev/null
        sudo systemctl enable shadowsocks-libev 2>/dev/null
        echo "shadowsocks:shadowsocks-libev:$ss_port:/etc/shadowsocks-libev/config.json" >> /etc/conexão/smart.conf
        echo "$(date): Configuração padrão gerada para Shadowsocks (porta $ss_port, senha $ss_password)" >> "$log_file"
    fi

    # WireGuard
    if command -v wg >/dev/null; then
        local wg_port=51820
        local wg_interface="wg0"
        local private_key=$(wg genkey)
        local public_key=$(echo "$private_key" | wg pubkey)
        cat <<EOF | sudo tee /etc/wireguard/$wg_interface.conf
[Interface]
PrivateKey = $private_key
Address = 10.0.0.1/24
ListenPort = $wg_port
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $public_key
AllowedIPs = 10.0.0.2/32
EOF
        sudo systemctl enable wg-quick@$wg_interface 2>/dev/null
        echo "wireguard:wg-quick@$wg_interface:$wg_port:/etc/wireguard/$wg_interface.conf" >> /etc/conexão/smart.conf
        echo "$(date): Configuração padrão gerada para WireGuard (interface $wg_interface, porta $wg_port)" >> "$log_file"
    fi

    # V2Ray
    if command -v v2ray >/dev/null; then
        local v2ray_port=10086
        local v2ray_id=$(uuidgen)
        cat <<EOF | sudo tee /usr/local/etc/v2ray/config.json
{
  "inbounds": [{
    "port": $v2ray_port,
    "protocol": "vmess",
    "settings": {
      "clients": [{ "id": "$v2ray_id" }]
    },
    "streamSettings": { "network": "tcp" }
  }],
  "outbounds": [{
    "protocol": "freedom"
  }]
}
EOF
        sudo systemctl restart v2ray 2>/dev/null
        sudo systemctl enable v2ray 2>/dev/null
        echo "v2ray:v2ray:$v2ray_port:/usr/local/etc/v2ray/config.json" >> /etc/conexão/smart.conf
        echo "$(date): Configuração padrão gerada para V2Ray (porta $v2ray_port, ID $v2ray_id)" >> "$log_file"
    fi

    # OpenVPN
    if command -v openvpn >/dev/null; then
        local ovpn_port=1194
        cat <<EOF | sudo tee /etc/openvpn/server.conf
port $ovpn_port
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh2048.pem
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
cipher AES-256-CBC
persist-key
persist-tun
verb 3
EOF
        echo "openvpn:openvpn:$ovpn_port:/etc/openvpn/server.conf" >> /etc/conexão/smart.conf
        echo "$(date): Configuração padrão gerada para OpenVPN (porta $ovpn_port). Certificados manuais necessários." >> "$log_file"
    fi

    echo "Configurações padrão geradas e salvas em /etc/conexão/smart.conf."
    echo "Pressione Enter para continuar..."
    read
}

# Função para configurar V2Ray
configure_v2ray() {
    clear
    echo "Configurando V2Ray..."
    echo "Digite a porta (padrão: 10086):"
    read -p "> " port
    port=${port:-10086}
    echo "Escolha o transporte:"
    echo "1) TCP"
    echo "2) WebSocket"
    echo "3) gRPC"
    read -p "> " transport
    local stream_settings=""
    case "$transport" in
        2)
            stream_settings='"network": "ws", "wsSettings": {"path": "/v2ray"}'
            ;;
        3)
            stream_settings='"network": "grpc", "grpcSettings": {"serviceName": "v2ray"}'
            ;;
        *)
            stream_settings='"network": "tcp"'
            ;;
    esac
    cat <<EOF | sudo tee /usr/local/etc/v2ray/config.json
{
  "inbounds": [{
    "port": $port,
    "protocol": "vmess",
    "settings": {
      "clients": [{ "id": "b831381d-6324-4d53-ad4f-8cda48b30811" }]
    },
    "streamSettings": { $stream_settings }
  }],
  "outbounds": [{
    "protocol": "freedom"
  }]
}
EOF
    sudo systemctl restart v2ray
    echo "V2Ray configurado na porta $port com transporte ${transport:-TCP}."
    echo "Pressione Enter para continuar..."
    read
}

# Função para desinstalar V2Ray
uninstall_v2ray() {
    clear
    echo "Desinstalando V2Ray..."
    sudo systemctl stop v2ray
    sudo rm -rf /usr/local/etc/v2ray /usr/local/bin/v2ray
    echo "V2Ray desinstalado. Pressione Enter para continuar..."
    read
}

# Função para instalar XRay
install_xray() {
    clear
    echo "Instalando XRay..."
    bash <(curl -L https://github.com/XTLS/Xray-core/releases/latest/download/install-release.sh)
    echo "XRay instalado. Pressione Enter para continuar..."
    read
}

# Função para configurar XRay
configure_xray() {
    clear
    echo "Configurando XRay..."
    echo "Digite a porta (padrão: 10086):"
    read -p "> " port
    port=${port:-10086}
    echo "Escolha o transporte:"
    echo "1) TCP"
    echo "2) WebSocket"
    echo "3) gRPC"
    read -p "> " transport
    local stream_settings=""
    case "$transport" in
        2)
            stream_settings='"network": "ws", "wsSettings": {"path": "/xray"}'
            ;;
        3)
            stream_settings='"network": "grpc", "grpcSettings": {"serviceName": "xray"}'
            ;;
        *)
            stream_settings='"network": "tcp"'
            ;;
    esac
    cat <<EOF | sudo tee /usr/local/etc/xray/config.json
{
  "inbounds": [{
    "port": $port,
    "protocol": "vmess",
    "settings": {
      "clients": [{ "id": "b831381d-6324-4d53-ad4f-8cda48b30811" }]
    },
    "streamSettings": { $stream_settings }
  }],
  "outbounds": [{
    "protocol": "freedom"
  }]
}
EOF
    sudo systemctl restart xray
    echo "XRay configurado na porta $port com transporte ${transport:-TCP}."
    echo "Pressione Enter para continuar..."
    read
}

# Função para desinstalar XRay
uninstall_xray() {
    clear
    echo "Desinstalando XRay..."
    sudo systemctl stop xray
    sudo rm -rf /usr/local/etc/xray /usr/local/bin/xray
    echo "XRay desinstalado. Pressione Enter para continuar..."
    read
}

# Função para instalar SlowDNS
install_slowdns() {
    clear
    echo "Instalando SlowDNS..."
    echo "SlowDNS requer configuração manual. Consulte: https://github.com/ferrybig/slowdns"
    echo "Pressione Enter para continuar..."
    read
}

# Função para configurar SlowDNS
configure_slowdns() {
    clear
    echo "Configurando SlowDNS..."
    echo "Configuração manual necessária. Consulte a documentação do SlowDNS."
    echo "Pressione Enter para continuar..."
    read
}

# Função para desinstalar SlowDNS
uninstall_slowdns() {
    clear
    echo "Desinstalando SlowDNS..."
    echo "Remova manualmente os arquivos de configuração do SlowDNS."
    echo "Pressione Enter para continuar..."
    read
}

# Função para instalar BadVPN
install_badvpn() {
    clear
    echo "Instalando BadVPN..."
    if [[ -f /etc/debian_version ]]; then
        sudo apt update
        sudo apt install cmake git -y
        git clone https://github.com/ambrop72/badvpn.git /tmp/badvpn
        cd /tmp/badvpn
        cmake . && make && sudo make install
        cd -
    else
        echo "Sistema não suportado para instalação automática."
    fi
    echo "BadVPN instalado. Pressione Enter para continuar..."
    read
}

# Função para configurar BadVPN
configure_badvpn() {
    clear
    echo "Configurando BadVPN..."
    echo "Digite a porta UDP (padrão: 7300):"
    read -p "> " port
    port=${port:-7300}
    sudo badvpn-udpgw --listen-addr 127.0.0.1:$port &
    echo "BadVPN configurado na porta $port."
    echo "Pressione Enter para continuar..."
    read
}

# Função para desinstalar BadVPN
uninstall_badvpn() {
    clear
    echo "Desinstalando BadVPN..."
    sudo rm -rf /usr/local/bin/badvpn*
    echo "BadVPN desinstalado. Pressione Enter para continuar..."
    read
}

# Função para instalar UDPGW
install_udpgw() {
    clear
    echo "Instalando UDPGW..."
    echo "UDPGW requer configuração manual. Consulte: https://github.com/bol-van/udpgw"
    echo "Pressione Enter para continuar..."
    read
}

# Função para configurar UDPGW
configure_udpgw() {
    clear
    echo "Configurando UDPGW..."
    echo "Configuração manual necessária. Consulte a documentação do UDPGW."
    echo "Pressione Enter para continuar..."
    read
}

# Função para desinstalar UDPGW
uninstall_udpgw() {
    clear
    echo "Desinstalando UDPGW..."
    echo "Remova manualmente os arquivos de configuração do UDPGW."
    echo "Pressione Enter para continuar..."
    read
}

# Função para instalar Shadowsocks
install_shadowsocks() {
    clear
    echo "Instalando Shadowsocks..."
    if [[ -f /etc/debian_version ]]; then
        sudo apt update
        sudo apt install shadowsocks-libev -y
    elif [[ -f /etc/redhat-release ]]; then
        sudo yum install epel-release -y
        sudo yum install shadowsocks-libev -y
    else
        echo "Sistema não suportado."
    fi
    echo "Shadowsocks instalado. Pressione Enter para continuar..."
    read
}

# Função para configurar Shadowsocks
configure_shadowsocks() {
    clear
    echo "Configurando Shadowsocks..."
    echo "Digite a porta (padrão: 8388):"
    read -p "> " port
    port=${port:-8388}
    echo "Digite a senha (ex.: mypassword):"
    read -p "> " password
    echo "Usar ofuscação (v2ray-plugin com TLS/WebSocket)? (s/n)"
    read -p "> " use_obfs
    local plugin=""
    local plugin_opts=""
    if [[ "$use_obfs" == "s" ]]; then
        echo "Escolha o modo de ofuscação:"
        echo "1) TLS"
        echo "2) WebSocket"
        read -p "> " obfs_mode
        if [[ "$obfs_mode" == "1" ]]; then
            plugin="v2ray-plugin"
            plugin_opts="server;tls;host=example.com"
        elif [[ "$obfs_mode" == "2" ]]; then
            plugin="v2ray-plugin"
            plugin_opts="server;path=/ws"
        fi
        if [[ -n "$plugin" && ! -f /usr/local/bin/v2ray-plugin ]]; then
            echo "Instalando v2ray-plugin..."
            wget https://github.com/shadowsocks/v2ray-plugin/releases/latest/download/v2ray-plugin-linux-amd64.tar.gz -O /tmp/v2ray-plugin.tar.gz
            tar -xzf /tmp/v2ray-plugin.tar.gz -C /usr/local/bin
            mv /usr/local/bin/v2ray-plugin-linux-amd64 /usr/local/bin/v2ray-plugin
            chmod +x /usr/local/bin/v2ray-plugin
        fi
    fi
    cat <<EOF | sudo tee /etc/shadowsocks-libev/config.json
{
    "server":"0.0.0.0",
    "server_port":$port,
    "local_port":1080,
    "password":"$password",
    "timeout":60,
    "method":"aes-256-gcm",
    "plugin":"$plugin",
    "plugin_opts":"$plugin_opts"
}
EOF
    sudo systemctl restart shadowsocks-libev
    sudo systemctl enable shadowsocks-libev
    echo "Shadowsocks configurado na porta $port${plugin:+ com ofuscação ($plugin)}."
    echo "Pressione Enter para continuar..."
    read
}

# Função para desinstalar Shadowsocks
uninstall_shadowsocks() {
    clear
    echo "Desinstalando Shadowsocks..."
    sudo systemctl stop shadowsocks-libev
    if [[ -f /etc/debian_version ]]; then
        sudo apt remove --purge shadowsocks-libev -y
    elif [[ -f /etc/redhat-release ]]; then
        sudo yum remove shadowsocks-libev -y
    fi
    sudo rm -rf /etc/shadowsocks-libev
    echo "Shadowsocks desinstalado. Pressione Enter para continuar..."
    read
}

# Função para instalar WireGuard
install_wireguard() {
    clear
    echo "Instalando WireGuard..."
    if [[ -f /etc/debian_version ]]; then
        if [[ $(grep -oP '(?<=^DISTRIB_RELEASE=).+' /etc/lsb-release 2>/dev/null) == "18.04" ]]; then
            sudo add-apt-repository ppa:wireguard/wireguard -y
        fi
        sudo apt update
        sudo apt install wireguard -y
    elif [[ -f /etc/redhat-release ]]; then
        sudo yum install epel-release -y
        sudo yum install wireguard-tools -y
    else
        echo "Sistema não suportado."
    fi
    echo "WireGuard instalado. Pressione Enter para continuar..."
    read
}

# Função para configurar WireGuard
configure_wireguard() {
    clear
    echo "Configurando WireGuard..."
    echo "Digite o nome da interface (ex.: wg0):"
    read -p "> " interface
    echo "Digite a porta (padrão: 51820):"
    read -p "> " port
    port=${port:-51820}
    private_key=$(wg genkey)
    public_key=$(echo "$private_key" | wg pubkey)
    cat <<EOF | sudo tee /etc/wireguard/$interface.conf
[Interface]
PrivateKey = $private_key
Address = 10.0.0.1/24
ListenPort = $port
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $public_key
AllowedIPs = 10.0.0.2/32
EOF
    sudo wg-quick up "$interface"
    sudo systemctl enable wg-quick@$interface
    echo "WireGuard configurado na interface $interface, porta $port."
    echo "Pressione Enter para continuar..."
    read
}

# Função para desinstalar WireGuard
uninstall_wireguard() {
    clear
    echo "Desinstalando WireGuard..."
    sudo systemctl stop wg-quick@wg0
    sudo systemctl disable wg-quick@wg0
    if [[ -f /etc/debian_version ]]; then
        sudo apt remove --purge wireguard -y
    elif [[ -f /etc/redhat-release ]]; then
        sudo yum remove wireguard-tools -y
    fi
    sudo rm -rf /etc/wireguard
    echo "WireGuard desinstalado. Pressione Enter para continuar..."
    read
}

# Função para gerenciar cada conexão
manage_connection() {
    local service_name="$1"
    local service="$2"
    local cmd="$3"
    local default_port="$4"
    local config_file="$5"
    local install_func="$6"
    local configure_func="$7"
    local uninstall_func="$8"

    while true; do
        draw_submenu "$service_name"
        read option
        case $option in
            1) check_status "$service" "$cmd" ;;
            2) start_stop "$service" ;;
            3) $install_func ;;
            4) open_ports "$service_name" "$default_port" ;;
            5) list_ports "$service_name" "$default_port" ;;
            6) remove_ports "$service_name" "$default_port" ;;
            7) $configure_func ;;
            8) $uninstall_func ;;
            9) change_ports "$service" "$config_file" "$default_port" ;;
            10) break ;;
            *) echo "Opção inválida! Pressione Enter para continuar..."; read ;;
        esac
    done
}

# Loop principal
main() {
    while true; do
        draw_main_menu
        read option
        case $option in
            1) manage_connection "Proxy" "squid" "squid" "3128" "/etc/squid/squid.conf" "install_proxy" "configure_proxy" "uninstall_proxy" ;;
            2) manage_connection "Proxy WebSocket" "wstunnel" "wstunnel" "8080" "" "install_websocket" "configure_websocket" "uninstall_websocket" ;;
            3) manage_connection "SSH Proxy" "sshuttle" "sshuttle" "22" "" "install_ssh_proxy" "configure_ssh_proxy" "uninstall_ssh_proxy" ;;
            4) manage_connection "SSL Tunnel" "stunnel4" "stunnel" "443" "/etc/stunnel/stunnel.conf" "install_ssl_tunnel" "configure_ssl_tunnel" "uninstall_ssl_tunnel" ;;
            5) manage_connection "SSL Proxy" "squid" "squid" "3128" "/etc/squid/squid.conf" "install_proxy" "configure_proxy" "uninstall_proxy" ;;
            6) manage_connection "OpenVPN" "openvpn" "openvpn" "1194" "/etc/openvpn/server.conf" "install_openvpn" "configure_openvpn" "uninstall_openvpn" ;;
            7) manage_connection "V2Ray" "v2ray" "v2ray" "10086" "/usr/local/etc/v2ray/config.json" "install_v2ray" "configure_v2ray" "uninstall_v2ray" ;;
            8) manage_connection "XRay" "xray" "xray" "10086" "/usr/local/etc/xray/config.json" "install_xray" "configure_xray" "uninstall_xray" ;;
            9) manage_connection "SlowDNS" "slowdns" "slowdns" "53" "" "install_slowdns" "configure_slowdns" "uninstall_slowdns" ;;
            10) manage_connection "BadVPN" "badvpn-udpgw" "badvpn-udpgw" "7300" "" "install_badvpn" "configure_badvpn" "uninstall_badvpn" ;;
            11) manage_connection "UDPGW" "udpgw" "udpgw" "7300" "" "install_udpgw" "configure_udpgw" "uninstall_udpgw" ;;
            12) manage_connection "Shadowsocks" "shadowsocks-libev" "ss-server" "8388" "/etc/shadowsocks-libev/config.json" "install_shadowsocks" "configure_shadowsocks" "uninstall_shadowsocks" ;;
            13) manage_connection "WireGuard" "wg-quick@wg0" "wg" "51820" "/etc/wireguard/wg0.conf" "install_wireguard" "configure_wireguard" "uninstall_wireguard" ;;
            14) smart_connect ;;
            15) echo "Saindo..."; exit 0 ;;
            *) echo "Opção inválida! Pressione Enter para continuar..."; read ;;
        esac
    done
}

# Verificar dependências
if ! command -v figlet >/dev/null; then
    echo "O comando 'figlet' não está instalado. Instale-o para o título do menu."
    echo "No Debian/Ubuntu: sudo apt install figlet"
    echo "No Red Hat/CentOS: sudo yum install figlet"
    exit 1
fi

# Iniciar o programa
main