
#---------------------------------------------------------
#  Gerenciador Inteligente de Proxies & Usuários SSH
#  Autor........: VOCÊ
#  Data.........: $(date +%d/%m/%Y)
#  Testado em...: Ubuntu 20.04/22.04 e Debian 11
#---------------------------------------------------------

# === Cores ===
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; BLUE="\e[34m"; CYAN="\e[36m"; RESET="\e[0m"

# === Utilidades ===
pausa(){ read -rp $'\nPressione <Enter> para continuar...'; }
linha(){ printf "${CYAN}---------------------------------------------------------${RESET}\n"; }
msg(){ printf "${GREEN}[✔]${RESET} %s\n" "$1"; }
erro(){ printf "${RED}[✖] %s${RESET}\n" "$1"; }

# === Pré-requisitos ===
instalar_prereqs(){
    linha; echo -e "${BLUE}Instalando dependências básicas...${RESET}"
    apt update && \
    apt install -y curl wget git build-essential pkg-config \
                   software-properties-common coreutils \
                   lsb-release ca-certificates gnupg
    msg "Dependências instaladas."
}

# === Proxy WebSocket (Websocat) ===
instalar_websocket(){
    linha; echo -e "${BLUE}Instalando Websocat (Proxy WebSocket)...${RESET}"
    local BIN="/usr/local/bin/websocat"
    if [[ ! -x $BIN ]]; then
        wget -qO $BIN https://github.com/vi/websocat/releases/latest/download/websocat.x86_64-unknown-linux-musl
        chmod +x $BIN
    fi
    # Exemplo de serviço systemd
    cat >/etc/systemd/system/websocat.service <<'EOF'
[Unit]
Description=WebSocket TCP Tunnel
After=network.target

[Service]
ExecStart=/usr/local/bin/websocat -s 0.0.0.0:8080 tcp:127.0.0.1:22
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable --now websocat
    msg "Websocat ativo em ws://IP:8080 -> 127.0.0.1:22"
}

# === Proxy SOCKS5 (Dante) ===
instalar_socks(){
    linha; echo -e "${BLUE}Instalando Dante SOCKS5...${RESET}"
    apt install -y dante-server
    cat >/etc/danted.conf <<'EOF'
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = 1080
external: eth0
method: username none
user.notprivileged: nobody
client pass {
        from: 0.0.0.0/0 to: 0.0.0.0/0
        log: connect disconnect
}
socks pass {
        from: 0.0.0.0/0 to: 0.0.0.0/0
        command: connect bind
        log: connect disconnect
}
EOF
    systemctl restart danted && systemctl enable danted
    msg "SOCKS5 ativo na porta 1080."
}

# === SSL Tunnel (Stunnel) ===
instalar_stunnel(){
    linha; echo -e "${BLUE}Instalando Stunnel...${RESET}"
    apt install -y stunnel4
    # Gerar certificado autoassinado simples
    openssl req -new -x509 -days 365 -nodes \
        -subj "/CN=$(hostname)" \
        -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem
    chmod 600 /etc/stunnel/stunnel.pem
    cat >/etc/stunnel/stunnel.conf <<'EOF'
cert = /etc/stunnel/stunnel.pem
[ssh]
accept = 443
connect = 22
EOF
    sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4
    systemctl restart stunnel4 && systemctl enable stunnel4
    msg "Stunnel ativo na porta 443 -> 22."
}

# === SlowDNS (iodine) ===
instalar_slowdns(){
    linha; echo -e "${BLUE}Instalando Iodine (SlowDNS)...${RESET}"
    apt install -y iodine
    systemctl enable --now iodined
    echo -e "${YELLOW}Ajuste seu domínio NS e configure iodined manualmente.${RESET}"
}

# === BadVPN UDPGW ===
instalar_badvpn(){
    linha; echo -e "${BLUE}Instalando BadVPN UDPGW...${RESET}"
    apt install -y badvpn
    # Serviço systemd exemplo
    cat >/etc/systemd/system/badvpn.service <<'EOF'
[Unit]
Description=BadVPN UDPGW
After=network.target

[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 0.0.0.0:7300
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable --now badvpn
    msg "BadVPN em 0.0.0.0:7300."
}

# === HAProxy ===
instalar_haproxy(){
    linha; echo -e "${BLUE}Instalando HAProxy...${RESET}"
    apt install -y haproxy
    cat >/etc/haproxy/haproxy.cfg <<'EOF'
global
  log /dev/log local0
  maxconn 4000
defaults
  log     global
  mode    tcp
  timeout connect 10s
  timeout client  1m
  timeout server  1m
frontend ssh-in
  bind *:2222
  default_backend ssh-nodes
backend ssh-nodes
  server s1 127.0.0.1:22 check
EOF
    systemctl restart haproxy && systemctl enable haproxy
    msg "HAProxy balanceando SSH na porta 2222."
}

# === RustyProxy (via cargo) ===
instalar_rustyproxy(){
    linha; echo -e "${BLUE}Instalando RustyProxy...${RESET}"
    if ! command -v cargo &>/dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source $HOME/.cargo/env
    fi
    cargo install rustyproxy
    cat >/etc/systemd/system/rustyproxy.service <<'EOF'
[Unit]
Description=RustyProxy
After=network.target

[Service]
ExecStart=/root/.cargo/bin/rustyproxy -l 0.0.0.0:3128
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable --now rustyproxy
    msg "RustyProxy ativo na porta 3128."
}

# === Usuário SSH com validade e limite ===
criar_usuario(){
    linha; echo -e "${BLUE}Criar novo usuário SSH...${RESET}"
    read -rp "Login.............: " USR
    read -rp "Senha.............: " -s PWD; echo
    read -rp "Dias de validade..: " DIAS
    read -rp "Máx sessões (pam_limits) [padrão:2]: " LIM
    LIM=${LIM:-2}

    # Cria usuário expirando em X dias
    useradd -m -s /bin/bash -e $(date -d "+$DIAS day" +%Y-%m-%d) "$USR"
    echo "$USR:$PWD" | chpasswd
    echo "$USR  hard  maxlogins  ${LIM}" >> /etc/security/limits.conf
    msg "Usuário $USR criado. Expira em $DIAS dia(s). Limite: $LIM sessões."
}

# === Menu Interativo ===
mostrar_menu(){
    clear
    linha
    echo -e "${YELLOW}GERENCIADOR INTELIGENTE DE PROXIES & SSH${RESET}"
    linha
    echo -e "${GREEN}1${RESET} - Instalar dependências básicas"
    echo -e "${GREEN}2${RESET} - Instalar Proxy WebSocket (Websocat)"
    echo -e "${GREEN}3${RESET} - Instalar Proxy SOCKS5 (Dante)"
    echo -e "${GREEN}4${RESET} - Instalar SSL Tunnel (Stunnel)"
    echo -e "${GREEN}5${RESET} - Instalar SlowDNS (Iodine)"
    echo -e "${GREEN}6${RESET} - Instalar BadVPN UDPGW"
    echo -e "${GREEN}7${RESET} - Instalar HAProxy"
    echo -e "${GREEN}8${RESET} - Instalar RustyProxy"
    echo -e "${GREEN}9${RESET} - Criar usuário SSH"
    echo -e "${GREEN}0${RESET} - Sair"
    linha
    read -rp "Escolha uma opção: " OP
}

# === Loop principal ===
while true; do
    mostrar_menu
    case "$OP" in
        1) instalar_prereqs; pausa ;;
        2) instalar_websocket; pausa ;;
        3) instalar_socks; pausa ;;
        4) instalar_stunnel; pausa ;;
        5) instalar_slowdns; pausa ;;
        6) instalar_badvpn; pausa ;;
        7) instalar_haproxy; pausa ;;
        8) instalar_rustyproxy; pausa ;;
        9) criar_usuario; pausa ;;
        0) linha; echo -e "${YELLOW}Saindo...${RESET}"; exit 0 ;;
        *) erro "Opção inválida!" ; sleep 1 ;;
    esac
done
