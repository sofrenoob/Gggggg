
# vpn_manager.sh - Gerenciador Proxy WebSocket Tunnel, SSL Tunnel e BadVPN
# Independente menu interativo no terminal

# --- Configurações iniciais ---

USERS_FILE="/opt/vpnmanager/users.json"

PROXY_WS_PORT=8080
SSL_TUNNEL_PORT=8443
BADVPN_PORT=7300

WEBSOCAT_BIN="/usr/local/bin/websocat"

# Serviços systemd
STUNNEL_SERVICE="stunnel4"
BADVPN_SERVICE="badvpn-udpgw"
WEBSOCAT_SERVICE="websocat-proxy"

# --- Funções utilitárias ---

function check_installed() {
  command -v "$1" >/dev/null 2>&1 || { echo "$1 não instalado. Abortando."; exit 1; }
}

function load_users() {
  if [ ! -f "$USERS_FILE" ]; then
    echo "[]" > "$USERS_FILE"
  fi
  USERS_JSON=$(cat "$USERS_FILE")
}

function save_users() {
  echo "$USERS_JSON" > "$USERS_FILE"
}

function generate_id() {
  echo $(date +%s%N | sha256sum | head -c 8)
}

# --- Funções para gerenciamento usuários ---

function add_user() {
  local login pass days limit expiry
  login=$(dialog --inputbox "Login do usuário:" 8 40 3>&1 1>&2 2>&3)
  pass=$(dialog --inputbox "Senha do usuário:" 8 40 3>&1 1>&2 2>&3)
  days=$(dialog --inputbox "Validade (dias):" 8 40 30 3>&1 1>&2 2>&3)
  limit=$(dialog --inputbox "Limite de dados (MB) (0 para ilimitado):" 8 60 0 3>&1 1>&2 2>&3)

  if [ -z "$login" ] || [ -z "$pass" ] || [ -z "$days" ]; then
    dialog --msgbox "Campos obrigatórios vazios!" 5 40
    return
  fi

  expiry=$(date -d "+$days days" +%Y-%m-%d)

  load_users

  if echo "$USERS_JSON" | jq --arg l "$login" '.[] | select(.login==$l)' | grep -q .; then
    dialog --msgbox "Login já existe!" 5 40
    return
  fi

  id=$(generate_id)

  USERS_JSON=$(echo "$USERS_JSON" | jq --argjson newUser \
    "{\"id\":\"$id\",\"login\":\"$login\",\"password\":\"$pass\",\"expiry\":\"$expiry\",\"limit\":$limit,\"used\":0}" '. += [$newUser]')

  save_users

  dialog --msgbox "Usuário $login criado com sucesso, expira em $expiry." 6 50
}

function list_users() {
  load_users
  local output="ID       | LOGIN    | EXPIRA    | LIMITE(MB) | USADO(MB)\n"
  output+="---------------------------------------------------------\n"
  echo "$USERS_JSON" | jq -r '.[] | "\(.id) | \(.login) | \(.expiry) | \(.limit) | \(.used)"' | while read line; do
    output+="$line\n"
  done
  dialog --msgbox "$output" 20 60
}

function remove_user() {
  load_users
  local id=$(dialog --inputbox "Digite o ID do usuário para remover:" 8 40 3>&1 1>&2 2>&3)
  if [ -z "$id" ]; then return; fi

  if ! echo "$USERS_JSON" | jq --arg i "$id" '.[] | select(.id==$i)' | grep -q .; then
    dialog --msgbox "Usuário não encontrado!" 5 40
    return
  fi

  USERS_JSON=$(echo "$USERS_JSON" | jq --arg i "$id" 'map(select(.id != $i))')
  save_users
  dialog --msgbox "Usuário removido com sucesso." 5 40
}

# --- Gerenciar portas ---

function edit_port() {
  local service_name=$1
  local current_port=$2
  local new_port

  new_port=$(dialog --inputbox "Digite a nova porta para $service_name:" 8 40 "$current_port" 3>&1 1>&2 2>&3)
  if [ -z "$new_port" ]; then return; fi
  if ! [[ "$new_port" =~ ^[0-9]+$ ]]; then
    dialog --msgbox "Porta inválida!" 5 40
    return
  fi

  case $service_name in
    "Proxy WebSocket")
      PROXY_WS_PORT=$new_port
      systemctl stop $WEBSOCAT_SERVICE
      # Criar ou atualizar serviço websocat
      create_websocat_service
      systemctl start $WEBSOCAT_SERVICE
      ;;
    "SSL Tunnel")
      SSL_TUNNEL_PORT=$new_port
      sed -i "s/^accept = .*/accept = $new_port/" /etc/stunnel/stunnel.conf
      systemctl restart $STUNNEL_SERVICE
      ;;
    "BadVPN")
      BADVPN_PORT=$new_port
      sed -i "s/--listen-addr 127.0.0.1:.*/--listen-addr 127.0.0.1:$new_port/" /etc/systemd/system/badvpn-udpgw.service
      systemctl daemon-reload
      systemctl restart $BADVPN_SERVICE
      ;;
  esac

  dialog --msgbox "$service_name porta alterada para $new_port." 5 50
}

# --- Criar serviço systemd para websocat proxy ---

function create_websocat_service() {
  cat > /etc/systemd/system/$WEBSOCAT_SERVICE.service <<EOF
[Unit]
Description=WebSocket Proxy Service
After=network.target

[Service]
ExecStart=$WEBSOCAT_BIN -s -t tcp-listen:$PROXY_WS_PORT
Restart=always

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable $WEBSOCAT_SERVICE
}

# --- Verificar usuários online (simples) ---

function count_online() {
  # Contar conexões TCP nas portas dos serviços
  local ws_count ssl_count badvpn_count
  ws_count=$(ss -tn state established sport = :$PROXY_WS_PORT | wc -l)
  ssl_count=$(ss -tn state established sport = :$SSL_TUNNEL_PORT | wc -l)
  badvpn_count=$(ss -tn state established sport = :$BADVPN_PORT | wc -l)
  echo "$ws_count $ssl_count $badvpn_count"
}

# --- Status dos serviços ---

function service_status() {
  local svc=$1
  if systemctl is-active --quiet $svc; then
    echo "Ativo"
  else
    echo "Inativo"
  fi
}

# --- Menu principal ---

function main_menu() {
  while true; do
    read ws_online ssl_online badvpn_online < <(count_online)
    ws_status=$(service_status $WEBSOCAT_SERVICE)
    ssl_status=$(service_status $STUNNEL_SERVICE)
    badvpn_status=$(service_status $BADVPN_SERVICE)

    exec 3>&1
    choice=$(dialog --clear --backtitle "Gerenciador de VPN - Proxy WebSocket, SSL Tunnel e BadVPN" \
      --title "Menu Principal" \
      --menu "Serviços Ativos:\n
Proxy WebSocket: $ws_status | Porta: $PROXY_WS_PORT | Online: $ws_online\n
SSL Tunnel: $ssl_status | Porta: $SSL_TUNNEL_PORT | Online: $ssl_online\n
BadVPN UDPGW: $badvpn_status | Porta: $BADVPN_PORT | Online: $badvpn_online\n\nEscolha uma opção:" 20 70 15 \
      1 "Gerenciar Proxy WebSocket" \
      2 "Gerenciar SSL Tunnel" \
      3 "Gerenciar BadVPN UDPGW" \
      4 "Gerenciar Usuários" \
      5 "Mostrar Usuários Online" \
      6 "Sair" \
      2>&1 1>&3)
    exec 3>&-

    case $choice in
      1) proxy_ws_menu ;;
      2) ssl_tunnel_menu ;;
      3) badvpn_menu ;;
      4) user_menu ;;
      5) show_online_users ;;
      6) clear; exit 0 ;;
      *) ;;
    esac
  done
}

# --- Submenus ---

function proxy_ws_menu() {
  while true; do
    exec 3>&1
    choice=$(dialog --clear --backtitle "Proxy WebSocket - Gerenciar" --menu "Escolha uma opção:" 15 50 10 \
    1 "Editar Porta (Atual: $PROXY_WS_PORT)" \
    2 "Reiniciar Serviço" \
    3 "Voltar" 2>&1 1>&3)
    exec 3>&-
    case $choice in
      1) edit_port "Proxy WebSocket" $PROXY_WS_PORT ;;
      2) systemctl restart $WEBSOCAT_SERVICE; dialog --msgbox "Serviço reiniciado." 5 40 ;;
      3) break ;;
      *) ;;
    esac
  done
}

function ssl_tunnel_menu() {
  while true; do
    exec 3>&1
    choice=$(dialog --clear --backtitle "SSL Tunnel (stunnel) - Gerenciar" --menu "Escolha uma opção:" 15 50 10 \
    1 "Editar Porta (Atual: $SSL_TUNNEL_PORT)" \
    2 "Reiniciar Serviço" \
    3 "Voltar" 2>&1 1>&3)
    exec 3>&-
    case $choice in
      1) edit_port "SSL Tunnel" $SSL_TUNNEL_PORT ;;
      2) systemctl restart $STUNNEL_SERVICE; dialog --msgbox "Serviço reiniciado." 5 40 ;;
      3) break ;;
      *) ;;
    esac
  done
}

function badvpn_menu() {
  while true; do
    exec 3>&1
    choice=$(dialog --clear --backtitle "BadVPN UDPGW - Gerenciar" --menu "Escolha uma opção:" 15 50 10 \
    1 "Editar Porta (Atual: $BADVPN_PORT)" \
    2 "Reiniciar Serviço" \
    3 "Voltar" 2>&1 1>&3)
    exec 3>&-
    case $choice in
      1) edit_port "BadVPN" $BADVPN_PORT ;;
      2) systemctl restart $BADVPN_SERVICE; dialog --msgbox "Serviço reiniciado." 5 40 ;;
      3) break ;;
      *) ;;
    esac
  done
}

function user_menu() {
  while true; do
    exec 3>&1
    choice=$(dialog --clear --backtitle "Gerenciar Usuários" --menu "Escolha uma opção:" 20 60 15 \
    1 "Criar Usuário" \
    2 "Listar Usuários" \
    3 "Remover Usuário" \
    4 "Voltar" 2>&1 1>&3)
    exec 3>&-
    case $choice in
      1) add_user ;;
      2) list_users ;;
      3) remove_user ;;
      4) break ;;
      *) ;;
    esac
  done
}

# --- Mostrar usuários online ---

function show_online_users() {
  load_users
  local ws_conns ssl_conns badvpn_conns
  ws_conns=$(ss -tn state established sport = :$PROXY_WS_PORT | awk '{print $6}' | sort | uniq -c | sort -nr)
  ssl_conns=$(ss -tn state established sport = :$SSL_TUNNEL_PORT | awk '{print $6}' | sort | uniq -c | sort -nr)
  badvpn_conns=$(ss -tn state established sport = :$BADVPN_PORT | awk '{print $6}' | sort | uniq -c | sort -nr)

  local output="Conexões atuais:\n\nProxy WebSocket:\n$ws_conns\n\nSSL Tunnel:\n$ssl_conns\n\nBadVPN UDPGW:\n$badvpn_conns\n\n"

  dialog --msgbox "$output" 20 70
}

# --- Inicialização ---

function check_dependencies() {
  for cmd in dialog jq ss stunnel4 systemctl; do
    check_installed $cmd
  done
  if [ ! -x "$WEBSOCAT_BIN" ]; then
    echo "Websocat não encontrado em $WEBSOCAT_BIN. Baixando..."
    wget -O $WEBSOCAT_BIN https://github.com/vi/websocat/releases/latest/download/websocat.x86_64-unknown-linux-gnu
    chmod +x $WEBSOCAT_BIN
  fi
}

function setup_services() {
  # Criar serviço websocat se não existir
  if ! systemctl list-units --full -all | grep -q $WEBSOCAT_SERVICE.service; then
    create_websocat_service
    systemctl enable $WEBSOCAT_SERVICE
  fi

  # Criar serviço badvpn se não existir
  if ! systemctl list-units --full -all | grep -q $BADVPN_SERVICE.service; then
    cat >/etc/systemd/system/$BADVPN_SERVICE.service <<EOF
[Unit]
Description=BadVPN UDPGW Service
After=network.target

[Service]
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:$BADVPN_PORT
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable $BADVPN_SERVICE
  fi

  # Reiniciar serviços para garantir que estão rodando
  systemctl restart $WEBSOCAT_SERVICE
  systemctl restart $BADVPN_SERVICE
  systemctl restart $STUNNEL_SERVICE
}

# --- Script principal ---

check_dependencies
load_ports
mkdir -p /opt/vpnmanager
touch "$USERS_FILE"
setup_services
main_menu
