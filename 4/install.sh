
#==============================================================================
#  VPN-SUITE – Painel CLI de Gerenciamento multi-túnel
#  Autor......: @alfalemos
#  Versão.....: 1.0  (11/05/2025)
#  Requisitos.: Ubuntu/Debian, root
#==============================================================================

shopt -s nocasematch
export LC_ALL=C
set -e

#-------------------------  CORES  --------------------------------------------
R="\e[31m"; G="\e[32m"; Y="\e[33m"; B="\e[34m"; C="\e[36m"; W="\e[97m"; Z="\e[0m"

#-------------------------  VARIÁVEIS  ----------------------------------------
BASE="/opt/vpn-suite"; mkdir -p "$BASE"
PORT_CFG="$BASE/porta.conf"; : > "$PORT_CFG"
KEEPALIVE="$BASE/hosts.lst"; touch "$KEEPALIVE"
MAIN_PORT=$(<"$PORT_CFG"); [[ -z $MAIN_PORT ]] && MAIN_PORT=443

#-------------------------  UTILITÁRIOS  --------------------------------------
need_root() {
    [[ $EUID -eq 0 ]] || { echo -e "${R}Execute como root!${Z}"; exit 1; }
}
tick() {
    printf "${G}[✔]${Z} %s\n" "$*"
}
pause() {
    read -rp $'\n<Enter> para continuar...'
}
ufw_allow() {
    command -v ufw &>/dev/null && ufw allow "$1"/tcp &>/dev/null
}
ufw_deny() {
    command -v ufw &>/dev/null && ufw delete allow "$1"/tcp &>/dev/null
}
ports_open() {
    ss -tulpnH | awk '{print $5}' | grep -Eo '[0-9]+$' | sort -un
}

#-------------------------  STATUS COMPACTO  ----------------------------------
draw_header() {
    clear
    printf "${C}╔════════════ VPN-SUITE ${W}(porta %s)${C} ════════════╗\n" "$MAIN_PORT"
    printf "║${B}CPU:${Z}%2s%%  ${B}Mem:${Z}%s/%sMB  ${B}Uptime:${Z}%s" \
        "$(grep 'cpu ' /proc/stat | awk '{u=$2+$4;s=$5} END{printf int(100*(u)/(u+s))}')" \
        "$(free -m | awk '/Mem:/{print $3}')" "$(free -m | awk '/Mem:/{print $2}')" \
        "$(uptime -p)"
    printf "  ${B}Users:${Z} %s║\n" "$(who | wc -l)"
    printf "║${B}Ports:${Z} %s║\n" "$(ports_open | xargs)"
    printf "╚═════════════════════════════════════════════════════╝${Z}\n"
}

#-------------------------  DEPENDÊNCIAS  -------------------------------------
install_prereqs() {
    apt update
    apt install -y curl wget git build-essential lsb-release ufw jq net-tools autossh \
        dante-server stunnel4 iodine badvpn haproxy || { echo -e "${R}Erro ao instalar dependências.${Z}"; exit 1; }
    
    # NodeJS para AnyProxy
    if ! command -v node &>/dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt install -y nodejs
    fi
    
    # Rust para RustyProxy
    if ! command -v cargo &>/dev/null; then
        curl https://sh.rustup.rs -sSf | sh -s -- -y
        source $HOME/.cargo/env
    fi
    
    npm -g ls anyproxy &>/dev/null || npm i -g anyproxy
    tick "Dependências instaladas."
}

#-------------------------  MÓDULOS -------------------------------------------
svc_websocket() {
    command -v websocat &>/dev/null || {
        wget -qO /usr/local/bin/websocat https://github.com/vi/websocat/releases/latest/download/websocat.x86_64-unknown-linux-musl
        chmod +x /usr/local/bin/websocat
    }
    cat >/etc/systemd/system/websocket.service <<EOF
[Unit]
Description=WebSocket ↔ SSH
[Service]
ExecStart=/usr/local/bin/websocat -s 127.0.0.1:80 tcp:127.0.0.1:22
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable --now websocket
    tick "WebSocket ativo (localhost:80)."
}

# [...] (Continuar com as outras funções de serviço, mantendo o mesmo padrão)

#-------------------------  HAProxy UNIFICADOR  -------------------------------
haproxy_cfg() {
    cat >/etc/haproxy/haproxy.cfg <<EOF
global
  log /dev/log local0
  maxconn 4000
defaults
  log global
  mode tcp
  timeout connect 10s
  timeout client 1m
  timeout server 1m

frontend fusion
  bind *:${MAIN_PORT}
  tcp-request inspect-delay 5s
  use_backend ssh       if { payload(0,3) -m bin 535348 }       # "SSH"
  use_backend tls       if { req_ssl_hello_type 1 }
  use_backend socks     if { payload_lv(0,1) 05 }               # SOCKS5
  use_backend websocket if { payload(0,3) -m sub -i GET }
  default_backend fallback

backend ssh       server s 127.0.0.1:22
backend tls       server t 127.0.0.1:444
backend socks     server k 127.0.0.1:1081
backend websocket server w 127.0.0.1:80
backend fallback  server f 127.0.0.1:3128
EOF
    systemctl restart haproxy && systemctl enable haproxy
    ufw_allow "$MAIN_PORT"
    tick "HAProxy configurado na porta $MAIN_PORT (múltiplos protocolos)."
}

# [...] (Continuar com as outras funções de usuários, conexões persistentes e menus)

#-------------------------  EXECUÇÃO  -----------------------------------------
need_root
haproxy_cfg        # garante HAProxy inicial
main_menu
