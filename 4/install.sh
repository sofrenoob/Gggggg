

#==============================================================================
#  VPN-SUITE – Painel CLI de Gerenciamento multi-túnel
#  Autor......: @alfalemos
#  Versão.....: 1.0
#  Requisitos.: Ubuntu/Debian, root
#==============================================================================

shopt -s nocasematch
export LC_ALL=C
set -e

#-------------------------  CORES  --------------------------------------------
R="\e[31m"; G="\e[32m"; Y="\e[33m"; B="\e[34m"; C="\e[36m"; W="\e[97m"; Z="\e[0m"

#-------------------------  FUNÇÕES DE UTILIDADE  -----------------------------
draw_header() {
    clear
    printf "${C}╔════════════ VPN-SUITE ═════════════╗\n"
    printf "║${B}CPU:${Z} %s%%  ${B}Mem:${Z} %s/%sMB  ${B}Uptime:${Z} %s\n" \
        "$(grep 'cpu ' /proc/stat | awk '{u=$2+$4;s=$5} END{printf int(100*(u)/(u+s))}')" \
        "$(free -m | awk '/Mem:/{print $3}')" "$(free -m | awk '/Mem:/{print $2}')" \
        "$(uptime -p)"
    printf "║${B}Portas abertas:${Z} %s║\n" "$(ss -tulpn | awk '{print $5}' | grep -Eo '[0-9]+$' | sort -un | xargs)"
    printf "╚═════════════════════════════════════╝${Z}\n"
}

pause() {
    read -rp $'\nPressione <Enter> para continuar...'
}

#-------------------------  MENU PRINCIPAL  -----------------------------------
main_menu() {
    while true; do
        draw_header
        echo -e "${G}1${Z} Instalar ferramentas"
        echo -e "${G}2${Z} Gerenciar conexões"
        echo -e "${G}3${Z} Criar/gerenciar usuários"
        echo -e "${G}0${Z} Sair"
        read -rp "Escolha uma opção: " op
        case $op in
            1) install_tools ;;
            2) manage_connections ;;
            3) manage_users ;;
            0) exit ;;
            *) echo -e "${R}Opção inválida!${Z}" ;;
        esac
    done
}

#-------------------------  INSTALAR FERRAMENTAS  ----------------------------
install_tools() {
    echo -e "${Y}Instalando ferramentas necessárias...${Z}"
    apt update
    apt install -y curl wget git build-essential lsb-release ufw jq net-tools autossh \
        dante-server stunnel4 iodine badvpn haproxy || { echo -e "${R}Erro ao instalar dependências.${Z}"; exit 1; }

    # Instalar NodeJS para AnyProxy
    if ! command -v node &>/dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt install -y nodejs
    fi

    # Instalar Rust para RustyProxy
    if ! command -v cargo &>/dev/null; then
        curl https://sh.rustup.rs -sSf | sh -s -- -y
        source $HOME/.cargo/env
    fi

    npm -g install anyproxy || { echo -e "${R}Erro ao instalar AnyProxy.${Z}"; exit 1; }

    echo -e "${G}Ferramentas instaladas com sucesso.${Z}"
    pause
}

#-------------------------  GERENCIAR CONEXÕES  -------------------------------
manage_connections() {
    while true; do
        draw_header
        echo -e "${G}1${Z} Configurar HAProxy"
        echo -e "${G}2${Z} Configurar Proxy WebSocket"
        echo -e "${G}3${Z} Configurar Proxy SOCKS"
        echo -e "${G}4${Z} Configurar SSL Tunnel"
        echo -e "${G}5${Z} Configurar SlowDNS"
        echo -e "${G}6${Z} Configurar BadVPN"
        echo -e "${G}0${Z} Voltar"
        read -rp "Escolha uma opção: " opt
        case $opt in
            1) configure_haproxy ;;
            2) configure_websocket ;;
            3) configure_socks ;;
            4) configure_ssl_tunnel ;;
            5) configure_slowdns ;;
            6) configure_badvpn ;;
            0) break ;;
            *) echo -e "${R}Opção inválida!${Z}" ;;
        esac
    done
}

#-------------------------  CONFIGURAÇÕES DE PROXY E SERVIÇOS  ---------------
configure_haproxy() {
    echo -e "${Y}Configurando HAProxy...${Z}"
    
    # Configuração básica do HAProxy
    cat >/etc/haproxy/haproxy.cfg <<EOF
global
    log /dev/log local0
    maxconn 2000

defaults
    log global
    mode tcp
    timeout connect 10s
    timeout client 1m
    timeout server 1m

frontend fusion
    bind *:443
    tcp-request inspect-delay 5s
    use_backend ssh       if { payload(0,3) -m bin 535348 }       # "SSH"
    use_backend tls       if { req_ssl_hello_type 1 }
    use_backend socks     if { payload_lv(0,1) 05 }               # SOCKS5
    use_backend websocket if { payload(0,3) -m sub -i GET }
    default_backend fallback

backend ssh       server s 127.0.0.1:22
backend tls       server t 127.0.0.1:444
backend socks     server k 127.0.0.1:1081
backend websocket server w 127.0.0.1:8080
backend fallback  server f 127.0.0.1:3128
EOF

    systemctl restart haproxy && systemctl enable haproxy
    echo -e "${G}HAProxy configurado com sucesso.${Z}"
    pause
}

configure_websocket() {
    echo -e "${Y}Configurando Proxy WebSocket...${Z}"
    
    # Instalação do WebSocket se não estiver presente
    if ! command -v websocat &>/dev/null; then
        wget -qO /usr/local/bin/websocat https://github.com/vi/websocat/releases/latest/download/websocat.x86_64-unknown-linux-musl
        chmod +x /usr/local/bin/websocat
    fi

    # Configuração do serviço
    cat >/etc/systemd/system/websocket.service <<EOF
[Unit]
Description=WebSocket ↔ SSH
[Service]
ExecStart=/usr/local/bin/websocat -s 127.0.0.1:8080 tcp:127.0.0.1:22
Restart=always
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload && systemctl enable --now websocket
    echo -e "${G}Proxy WebSocket configurado com sucesso.${Z}"
    pause
}

configure_socks() {
    echo -e "${Y}Configurando Proxy SOCKS...${Z}"
    
    # Configuração do SOCKS
    cat >/etc/danted.conf <<EOF
logoutput: /var/log/danted.log
internal: 127.0.0.1 port = 1081
external: eth0
method: username none
client pass { from: 0.0.0.0/0 to: 0.0.0.0/0 }
socks pass { from: 0.0.0.0/0 to: 0.0.0.0/0 }
EOF

    systemctl restart danted && systemctl enable danted
    echo -e "${G}Proxy SOCKS configurado com sucesso.${Z}"
    pause
}

configure_ssl_tunnel() {
    echo -e "${Y}Configurando SSL Tunnel...${Z}"
    
    # Geração do certificado SSL
    openssl req -new -x509 -days 365 -nodes -subj "/CN=$(hostname)" \
        -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem
    chmod 600 /etc/stunnel/stunnel.pem

    # Configuração do Stunnel
    cat >/etc/stunnel/stunnel.conf <<EOF
cert=/etc/stunnel/stunnel.pem
[ssh]
accept = 127.0.0.1:444
connect = 22
EOF

    sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4
    systemctl restart stunnel4 && systemctl enable stunnel4
    echo -e "${G}SSL Tunnel configurado com sucesso.${Z}"
    pause
}

configure_slowdns() {
    echo -e "${Y}Configurando SlowDNS...${Z}"
    
    systemctl enable --now iodined
    echo -e "${G}SlowDNS configurado com sucesso.${Z}"
    pause
}

configure_badvpn() {
    echo -e "${Y}Configurando BadVPN...${Z}"

    # Configuração do BadVPN
    cat >/etc/systemd/system/badvpn.service <<EOF
[Unit]
Description=BadVPN UDPGW
[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300
Restart=always
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload && systemctl enable --now badvpn
    echo -e "${G}BadVPN configurado com sucesso.${Z}"
    pause
}

#-------------------------  GERENCIAR USUÁRIOS  ------------------------------
manage_users() {
    while true; do
        draw_header
        echo -e "${G}1${Z} Criar usuário"
        echo -e "${G}2${Z} Informações do usuário"
        echo -e "${G}3${Z} Backup de usuários"
        echo -e "${G}0${Z} Voltar"
        read -rp "Escolha uma opção: " uopt
        case $uopt in
            1) create_user ;;
            2) user_info ;;
            3) backup_users ;;
            0) break ;;
            *) echo -e "${R}Opção inválida!${Z}" ;;
        esac
    done
}

create_user() {
    read -rp "Nome do usuário: " username
    read -rsp "Senha do usuário: " password
    echo
    read -rp "Dias de validade: " days
    useradd -m -s /bin/bash -e $(date -d "+$days days" +%F) "$username"
    echo "$username:$password" | chpasswd
    echo -e "${G}Usuário $username criado.${Z}"
    pause
}

user_info() {
    read -rp "Nome do usuário: " username
    chage -l "$username"
    lastlog -u "$username"
    pause
}

backup_users() {
    local f=/root/backup_users_$(date +%F).txt
    getent passwd | awk -F: '$3>=1000{print $1":"$3":"$6}' >"$f"
    echo -e "${G}Backup salvo em: $f${Z}"
    pause
}

#-------------------------  EXECUÇÃO DO SCRIPT  --------------------------------
main_menu
