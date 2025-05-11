
#==============================================================================
#  PROXY-MANAGER – Painel CLI de Gerenciamento de Conexões
#  Funcionalidades: sistema info, gestão de portas, WebSocket, SOCKS5, Stunnel,
#                   SlowDNS, BadVPN, HAProxy, RustyProxy, AnyProxy (node),
#                   criação/backup de usuários, conexão persistente (autossh)
#  Autor...: @alfalemos
#  Última..: 11/05/2025
#==============================================================================

shopt -s nocasematch
export LC_ALL=C

#--- Cores --------------------------------------------------------------------
R="\e[31m"; G="\e[32m"; Y="\e[33m"; B="\e[34m"; C="\e[36m"; W="\e[97m"; Z="\e[0m"
tick(){ printf "${G}[✔]${Z} %s\n" "$*"; }
warn(){ printf "${Y}[!]${Z} %s\n" "$*"; }
fail(){ printf "${R}[✖]${Z} %s\n" "$*"; }
pause(){ read -rp $'\nPressione <Enter> para continuar...'; }

#--- Variáveis globais --------------------------------------------------------
BASE_DIR="/opt/proxy-manager"
KEEPALIVE_LIST="$BASE_DIR/hosts.lst"
mkdir -p "$BASE_DIR"

#--- Funções utilitárias ------------------------------------------------------
is_root(){ [[ $EUID -eq 0 ]]; }
need_root(){ is_root || { fail "Execute como root!"; exit 1; }; }

port_open(){ ss -tulpn | awk '{print $5}' | grep -Eo '[0-9]+$' | sort -u; }

ufw_open(){ local p=$1
    if command -v ufw &>/dev/null; then ufw allow "$p"/tcp &>/dev/null; fi
}
ufw_close(){ local p=$1
    if command -v ufw &>/dev/null; then ufw delete allow "$p"/tcp &>/dev/null; fi
}

#--- Informações de sistema ---------------------------------------------------
sysinfo(){
    clear
    echo -e "${C}================  INFO DO SISTEMA  ================${Z}"
    printf "${B}Host:${Z} %s   ${B}Kernel:${Z} %s   ${B}Uptime:${Z} %s\n" \
           "$(hostname)" "$(uname -r)" "$(uptime -p)"
    printf "${B}CPU :${Z} %s núcleos  @ %s MHz\n" \
           "$(nproc)" "$(awk -F: '/cpu MHz/{print $2;exit}' /proc/cpuinfo)"
    printf "${B}Mem :${Z} %s MB livres / %s MB\n" \
           "$(free -m | awk '/Mem:/{print $4}')" \
           "$(free -m | awk '/Mem:/{print $2}')"
    printf "${B}Distribuição:${Z} "; lsb_release -d | cut -f2
    echo -e "${C}----------------------------------------------------${Z}"
    echo -e "${B}Portas abertas:${Z}"; port_open | xargs echo
    echo -e "${B}Serviços ativos:${Z}"
    systemctl --type=service --state=running --no-pager --no-legend | head
    echo -e "${B}Usuários online:${Z}"; who | awk '{print $1" ("$2")"}'
}

#--- Dependências básicas -----------------------------------------------------
install_prereqs(){
    apt update
    apt install -y curl wget git build-essential lsb-release \
       ufw jq net-tools autossh
}

#--- Gestão de portas ---------------------------------------------------------
menu_portas(){
  while true; do
    clear
    echo -e "${C}====== GERENCIAR PORTAS (UFW) ======${Z}"
    echo -e "${G}1${Z} - Abrir porta"
    echo -e "${G}2${Z} - Fechar porta"
    echo -e "${G}3${Z} - Listar portas abertas"
    echo -e "${G}0${Z} - Voltar"
    read -rp "Opção: " p
    case $p in
      1) read -rp "Porta a abrir: " pt; ufw_open "$pt"; tick "Porta $pt aberta"; pause;;
      2) read -rp "Porta a fechar: " pt; ufw_close "$pt"; tick "Porta $pt fechada"; pause;;
      3) ufw status numbered; pause;;
      0) break;;
      *) ;;
    esac
  done
}

#--- MÓDULOS DE SERVIÇO -------------------------------------------------------
# Cada módulo tem: instalar, start, stop, status

# WebSocket (Websocat) --------------------------------------------------------
ws_install(){
    local BIN=/usr/local/bin/websocat
    [[ -x $BIN ]] || {
      wget -qO $BIN https://github.com/vi/websocat/releases/latest/download/websocat.x86_64-unknown-linux-musl
      chmod +x $BIN
    }
    cat >/etc/systemd/system/websocket.service <<EOF
[Unit]
Description=WebSocket -> SSH
After=network.target
[Service]
ExecStart=$BIN -s 0.0.0.0:8080 tcp:127.0.0.1:22
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable --now websocket
    ufw_open 8080
    tick "WebSocket ativo na porta 8080"
}

# SOCKS5 (Dante) --------------------------------------------------------------
socks_install(){
    apt install -y dante-server
    cat >/etc/danted.conf <<'EOF'
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = 1080
external: eth0
method: username none
user.notprivileged: nobody
client pass{ from: 0.0.0.0/0 to: 0.0.0.0/0 }
socks pass{ from: 0.0.0.0/0 to: 0.0.0.0/0 }
EOF
    systemctl restart danted && systemctl enable danted
    ufw_open 1080
    tick "SOCKS5 na porta 1080"
}

# Stunnel ---------------------------------------------------------------------
ssl_install(){
    apt install -y stunnel4
    openssl req -new -x509 -days 365 -nodes \
       -subj "/CN=$(hostname)" \
       -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem
    chmod 600 /etc/stunnel/stunnel.pem
    cat >/etc/stunnel/stunnel.conf <<EOF
cert=/etc/stunnel/stunnel.pem
[ssh]
accept = 443
connect = 22
EOF
    sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4
    systemctl restart stunnel4 && systemctl enable stunnel4
    ufw_open 443
    tick "SSL Tunnel na porta 443"
}

# SlowDNS (iodine) ------------------------------------------------------------
slowdns_install(){
    apt install -y iodine
    systemctl enable --now iodined
    tick "Iodine instalado. Configure domínio NS manualmente."
}

# BadVPN ----------------------------------------------------------------------
badvpn_install(){
    apt install -y badvpn
    cat >/etc/systemd/system/badvpn.service <<EOF
[Unit]
Description=BadVPN UDPGW
[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 0.0.0.0:7300
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable --now badvpn
    ufw_open 7300
    tick "BadVPN em 7300"
}

# HAProxy ---------------------------------------------------------------------
haproxy_install(){
    apt install -y haproxy
cat >/etc/haproxy/haproxy.cfg <<'EOF'
global
  log /dev/log local0
  maxconn 4000
defaults
  log global
  mode tcp
  timeout connect 10s
  timeout client 1m
  timeout server 1m
frontend multi
  bind *:2222
  tcp-request inspect-delay 5s
  use_backend ssh if { payload(0,3) -m bin 535348 }     # "SSH" magic
  default_backend other
backend ssh
  server ssh1 127.0.0.1:22
backend other
  server ws1 127.0.0.1:8080
  server ssl1 127.0.0.1:443
EOF
    systemctl restart haproxy && systemctl enable haproxy
    ufw_open 2222
    tick "HAProxy multiprotocolo na porta 2222"
}

# RustyProxy ------------------------------------------------------------------
rustyproxy_install(){
    if ! command -v cargo &>/dev/null; then
        curl https://sh.rustup.rs -sSf | sh -s -- -y
        source $HOME/.cargo/env
    fi
    cargo install rustyproxy
    cat >/etc/systemd/system/rustyproxy.service <<EOF
[Unit]
Description=RustyProxy
[Service]
ExecStart=/root/.cargo/bin/rustyproxy -l 0.0.0.0:3128
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable --now rustyproxy
    ufw_open 3128
    tick "RustyProxy em 3128"
}

# AnyProxy (NodeJS) -----------------------------------------------------------
anyproxy_install(){
    apt install -y nodejs npm
    npm install -g anyproxy
    cat >/etc/systemd/system/anyproxy.service <<EOF
[Unit]
Description=AnyProxy
[Service]
ExecStart=/usr/bin/anyproxy --port 8899 --intercept false
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable --now anyproxy
    ufw_open 8899
    tick "AnyProxy em 8899"
}

#--- Usuários SSH -------------------------------------------------------------
user_create(){
    read -rp "Login: " usr
    read -rsp "Senha: " pwd; echo
    read -rp "Dias de validade: " dias
    read -rp "Máx sessões (default 2): " lim; lim=${lim:-2}
    useradd -m -s /bin/bash -e $(date -d "+$dias days" +%F) "$usr"
    echo "$usr:$pwd" | chpasswd
    echo "$usr  hard  maxlogins  $lim" >> /etc/security/limits.conf
    tick "Usuário $usr criado."
}

user_info(){
    read -rp "Usuário: " usr
    echo "----- $(passwd -S $usr) -----"
    chage -l "$usr"
    lastlog -u "$usr"
}

user_backup(){
    local file="/root/backup_users_$(date +%F).txt"
    getent passwd | awk -F: '$3>=1000{print $1":"$3":"$6}' > "$file"
    tick "Backup salvo em $file"
}

user_menu(){
  while true; do
    clear
    echo -e "${C}======== GERENCIAR USUÁRIOS SSH ========${Z}"
    echo -e "${G}1${Z} - Criar usuário"
    echo -e "${G}2${Z} - Informações de usuário"
    echo -e "${G}3${Z} - Backup de usuários"
    echo -e "${G}0${Z} - Voltar"
    read -rp "Opção: " uop
    case $uop in
      1) user_create; pause;;
      2) user_info; pause;;
      3) user_backup; pause;;
      0) break;;
    esac
  done
}

#--- Conexão Persistente (KeepAlive) -----------------------------------------
keepalive_add(){
    read -rp "Host (user@ip:porta): " h
    echo "$h" >> "$KEEPALIVE_LIST"
    systemctl restart proxy-keepalive
}

keepalive_service(){
cat >/etc/systemd/system/proxy-keepalive.service <<EOF
[Unit]
Description=Manter túneis autossh para hosts externos
After=network.target
[Service]
Type=simple
ExecStart=/bin/bash -c '
  while read line; do
    [[ -z \$line ]] && continue
    user=\${line%@*}; hostport=\${line#*@}
    host=\${hostport%%:*}; port=\${hostport##*:}
    autossh -M 0 -f -N -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -p \$port \$user@\$host
  done < "$KEEPALIVE_LIST"
  sleep 600
'
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now proxy-keepalive
}

keepalive_menu(){
  [[ -f $KEEPALIVE_LIST ]] || touch "$KEEPALIVE_LIST"
  keepalive_service
  while true; do
    clear
    echo -e "${C}====== CONEXÃO PERSISTENTE (autossh) ======${Z}"
    echo -e "${G}1${Z} - Adicionar host"
    echo -e "${G}2${Z} - Listar hosts"
    echo -e "${G}0${Z} - Voltar"
    read -rp "Opção: " kop
    case $kop in
      1) keepalive_add; pause;;
      2) cat "$KEEPALIVE_LIST"; pause;;
      0) break;;
    esac
  done
}

#--- Menu de serviços genérico -----------------------------------------------
generic_service_menu(){
    local name=$1 install_fn=$2
    while true; do
        clear
        echo -e "${C}====== $name ======${Z}"
        echo -e "${G}1${Z} - Instalar/Iniciar"
        echo -e "${G}2${Z} - Parar"
        echo -e "${G}3${Z} - Status"
        echo -e "${G}0${Z} - Voltar"
        read -rp "Opção: " op
        case $op in
          1) $install_fn; pause;;
          2) systemctl stop "$name"; tick "$name parado"; pause;;
          3) systemctl status "$name" --no-pager; pause;;
          0) break;;
        esac
    done
}

#--- Menu principal -----------------------------------------------------------
main_menu(){
  while true; do
    sysinfo
    echo -e "${G}1${Z} - Gerenciar Portas"
    echo -e "${G}2${Z} - WebSocket"
    echo -e "${G}3${Z} - SOCKS5"
    echo -e "${G}4${Z} - SSL Tunnel"
    echo -e "${G}5${Z} - SlowDNS"
    echo -e "${G}6${Z} - BadVPN"
    echo -e "${G}7${Z} - HAProxy"
    echo -e "${G}8${Z} - RustyProxy"
    echo -e "${G}9${Z} - AnyProxy"
    echo -e "${G}10${Z} - Usuários SSH"
    echo -e "${G}11${Z} - Conexão Persistente"
    echo -e "${G}99${Z} - Instalar dependências"
    echo -e "${G}0${Z} - Sair"
    read -rp "Escolha: " opc
    case $opc in
      1) menu_portas;;
      2) generic_service_menu "websocket" ws_install;;
      3) generic_service_menu "danted" socks_install;;
      4) generic_service_menu "stunnel4" ssl_install;;
      5) generic_service_menu "iodined" slowdns_install;;
      6) generic_service_menu "badvpn" badvpn_install;;
      7) generic_service_menu "haproxy" haproxy_install;;
      8) generic_service_menu "rustyproxy" rustyproxy_install;;
      9) generic_service_menu "anyproxy" anyproxy_install;;
      10) user_menu;;
      11) keepalive_menu;;
      99) install_prereqs; pause;;
      0) echo "Saindo..."; exit;;
    esac
  done
}

#--- Execução -----------------------------------------------------------------
need_root
main_menu
