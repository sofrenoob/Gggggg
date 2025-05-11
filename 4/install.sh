
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
need_root(){ [[ $EUID -eq 0 ]] || { echo -e "${R}Execute como root!${Z}"; exit 1; }; }
tick(){ printf "${G}[✔]${Z} %s\n" "$*"; }
pause(){ read -rp $'\n<Enter> para continuar...'; }
ufw_allow(){ command -v ufw &>/dev/null && ufw allow "$1"/tcp &>/dev/null; }
ufw_deny(){ command -v ufw &>/dev/null && ufw delete allow "$1"/tcp &>/dev/null; }
ports_open(){ ss -tulpnH | awk '{print $5}'|grep -Eo '[0-9]+$'|sort -un; }

#-------------------------  STATUS COMPACTO  ----------------------------------
draw_header(){
  clear
  printf "${C}╔════════════ VPN-SUITE ${W}(porta %s)${C} ════════════╗\n" "$MAIN_PORT"
  printf "║${B}CPU:${Z}%2s%%  ${B}Mem:${Z}%s/%sMB  ${B}Uptime:${Z}%s" \
     "$(grep 'cpu ' /proc/stat|awk '{u=$2+$4;s=$5} END{printf int(100*(u)/(u+s))}')" \
     "$(free -m|awk '/Mem:/{print $3}')" "$(free -m|awk '/Mem:/{print $2}')" \
     "$(uptime -p)"
  printf "  ${B}Users:${Z} %s║\n" "$(who|wc -l)"
  printf "║${B}Ports:${Z} %s║\n" "$(ports_open|xargs)"
  printf "╚═════════════════════════════════════════════════════╝${Z}\n"
}

#-------------------------  DEPENDÊNCIAS  -------------------------------------
install_prereqs(){
  apt update
  apt install -y curl wget git build-essential \
    lsb-release ufw jq net-tools autossh \
    dante-server stunnel4 iodine badvpn \
    haproxy
  # NodeJS para AnyProxy
  if ! command -v node &>/dev/null; then
      curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
      apt install -y nodejs
  fi
  # Rust para RustyProxy
  command -v cargo &>/dev/null || { curl https://sh.rustup.rs -sSf | sh -s -- -y; source $HOME/.cargo/env; }
  npm -g ls anyproxy &>/dev/null || npm i -g anyproxy
  tick "Dependências instaladas."
}

#-------------------------  MÓDULOS -------------------------------------------
# Cada função instala e registra serviço systemd

svc_websocket(){
  command -v websocat &>/dev/null || {
    wget -qO /usr/local/bin/websocat https://github.com/vi/websocat/releases/latest/download/websocat.x86_64-unknown-linux-musl
    chmod +x /usr/local/bin/websocat
  }
  cat >/etc/systemd/system/websocket.service <<EOF
[Unit] Description=WebSocket ↔ SSH
[Service] ExecStart=/usr/local/bin/websocat -s 127.0.0.1:8080 tcp:127.0.0.1:22
Restart=always
[Install] WantedBy=multi-user.target
EOF
  systemctl daemon-reload && systemctl enable --now websocket
  tick "WebSocket ativo (localhost:8080)."
}

svc_socks(){
  cat >/etc/danted.conf <<'EOF'
logoutput: /var/log/danted.log
internal: 127.0.0.1 port = 1081
external: eth0
method: username none
user.notprivileged: nobody
client pass{ from:0.0.0.0/0 to:0.0.0.0/0 }
socks pass{ from:0.0.0.0/0 to:0.0.0.0/0 }
EOF
  systemctl restart danted && systemctl enable danted
  tick "SOCKS5 ativo (localhost:1081)."
}

svc_stunnel(){
  openssl req -new -x509 -days 365 -nodes -subj "/CN=$(hostname)" \
      -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem
  chmod 600 /etc/stunnel/stunnel.pem
  cat >/etc/stunnel/stunnel.conf <<EOF
cert=/etc/stunnel/stunnel.pem
[ssh] accept = 127.0.0.1:444 connect = 22
EOF
  sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4
  systemctl restart stunnel4 && systemctl enable stunnel4
  tick "Stunnel ativo (localhost:444)."
}

svc_slowdns(){
  systemctl enable --now iodined
  tick "Iodine instalado (configure domínio manualmente)."
}

svc_badvpn(){
  cat >/etc/systemd/system/badvpn.service <<EOF
[Unit] Description=BadVPN UDPGW
[Service] ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300
Restart=always
[Install] WantedBy=multi-user.target
EOF
  systemctl daemon-reload && systemctl enable --now badvpn
  tick "BadVPN ativo (localhost:7300)"
}

svc_rusty(){
  cargo install rustyproxy --quiet || true
  cat >/etc/systemd/system/rustyproxy.service <<EOF
[Unit] Description=RustyProxy
[Service] ExecStart=/root/.cargo/bin/rustyproxy -l 127.0.0.1:3128
Restart=always
[Install] WantedBy=multi-user.target
EOF
  systemctl daemon-reload && systemctl enable --now rustyproxy
  tick "RustyProxy ativo (localhost:3128)"
}

svc_anyproxy(){
  cat >/etc/systemd/system/anyproxy.service <<EOF
[Unit] Description=AnyProxy
[Service] ExecStart=/usr/bin/anyproxy --port 8899 --intercept false
Restart=always
[Install] WantedBy=multi-user.target
EOF
  systemctl daemon-reload && systemctl enable --now anyproxy
  tick "AnyProxy ativo (localhost:8899)"
}

#-------------------------  HAProxy UNIFICADOR  -------------------------------
haproxy_cfg(){
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
backend websocket server w 127.0.0.1:8080
backend fallback  server f 127.0.0.1:3128
EOF
  systemctl restart haproxy && systemctl enable haproxy
  ufw_allow "$MAIN_PORT"
  tick "HAProxy configurado na porta $MAIN_PORT (múltiplos protocolos)."
}

#-------------------------  USUÁRIOS SSH  -------------------------------------
user_add(){
  read -rp "Login: " u; read -rsp "Senha: " p; echo
  read -rp "Dias de validade: " d; read -rp "Limite de sessões (2): " l; : ${l:=2}
  useradd -m -s /bin/bash -e $(date -d "+$d days" +%F) "$u"
  echo "$u:$p" | chpasswd
  echo "$u hard maxlogins $l" >> /etc/security/limits.conf
  tick "Usuário $u criado."
}

user_info(){
  read -rp "Login: " u; chage -l "$u"; lastlog -u "$u"
}

user_backup(){
  local f=/root/backup_users_$(date +%F).txt
  getent passwd | awk -F: '$3>=1000{print $1":"$3":"$6}' >"$f"
  tick "Backup salvo: $f"
}

#-------------------------  CONEXÃO PERSISTENTE  ------------------------------
keepalive_svc(){
cat >/etc/systemd/system/keepalive.service <<EOF
[Unit] Description=Conexões persistentes autossh
[Service] Type=simple
ExecStart=/bin/bash -c '
  while true; do
    while read line; do
       [[ -z \$line ]] && continue
       autossh -M 0 -f -N -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" \$line
    done < "$KEEPALIVE"
    sleep 600
  done'
Restart=always
[Install] WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable --now keepalive.service
}

keepalive_add(){ read -rp "autossh comando (user@host -p PORT -R ...): " h; echo "$h" >>"$KEEPALIVE"; systemctl restart keepalive.service; }

#-------------------------  MENUS  --------------------------------------------
menu_users(){
  while true; do
    draw_header
    echo -e "${G}1${Z} Criar login  ${G}2${Z} Info login  ${G}3${Z} Backup  ${G}0${Z} Voltar"
    read -rp "Opção: " o
    case $o in 1) user_add;; 2) user_info;; 3) user_backup;; 0) break; esac
    pause
  done
}

menu_keepalive(){
  keepalive_svc
  while true; do
    draw_header
    echo -e "${G}1${Z} Adicionar host   ${G}2${Z} Listar   ${G}0${Z} Voltar"
    read -rp "Opção: " k
    case $k in 1) keepalive_add;; 2) cat "$KEEPALIVE"; pause;; 0) break; esac
  done
}

menu_porta(){
  read -rp "Porta unificada desejada (atual $MAIN_PORT): " p
  [[ $p =~ ^[0-9]+$ ]] || { echo "Porta inválida"; pause; return; }
  ufw_deny "$MAIN_PORT"
  MAIN_PORT=$p; echo "$MAIN_PORT" >"$PORT_CFG"
  haproxy_cfg
  pause
}

menu_servicos(){
  while true; do
    draw_header
    echo -e "${G}1${Z} WebSocket  ${G}2${Z} SOCKS5  ${G}3${Z} SSL  ${G}4${Z} SlowDNS"
    echo -e "${G}5${Z} BadVPN     ${G}6${Z} RustyProxy  ${G}7${Z} AnyProxy  ${G}0${Z} Voltar"
    read -rp "Instalar/Iniciar serviço: " s
    case $s in
      1) svc_websocket;;
      2) svc_socks;;
      3) svc_stunnel;;
      4) svc_slowdns;;
      5) svc_badvpn;;
      6) svc_rusty;;
      7) svc_anyproxy;;
      0) break;;
    esac
    pause
  done
}

main_menu(){
  while true; do
    draw_header
    echo -e "${G}1${Z} Instalar dependências"
    echo -e "${G}2${Z} Definir porta unificada"
    echo -e "${G}3${Z} Gerenciar serviços"
    echo -e "${G}4${Z} Logins SSH"
    echo -e "${G}5${Z} Conexões persistentes"
    echo -e "${G}0${Z} Sair"
    read -rp "Escolha: " op
    case $op in
      1) install_prereqs; svc_websocket; svc_socks; svc_stunnel; svc_badvpn; svc_rusty; svc_anyproxy; haproxy_cfg; pause;;
      2) menu_porta;;
      3) menu_servicos;;
      4) menu_users;;
      5) menu_keepalive;;
      0) exit;;
    esac
  done
}

#-------------------------  EXECUÇÃO  -----------------------------------------
need_root
haproxy_cfg        # garante HAProxy inicial
main_menu
