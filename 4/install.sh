

# Vars
XRAY_CONFIG="/etc/xray/config.json"
SSL_CERT="/etc/xray/ssl/cert.pem"
SSL_KEY="/etc/xray/ssl/key.pem"
BADVPN_UDPGW_PORT=7300
DB_PATH="/opt/vpnmanager/vpnusers.db"
XRAY_SERVICE="xray"
BADVPN_SERVICE="badvpn-udpgw"

# Instalação e dependências
install_dependencies(){
    echo "Atualizando e instalando dependências..."
    apt update && apt upgrade -y
    apt install -y curl wget unzip python3 python3-pip python3-venv sqlite3 iptables socat dialog git cmake build-essential
}

# Instalar Xray-core
install_xray(){
    echo "Instalando Xray-core..."
    bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
}

# Criar certificado autoassinado
create_ssl_cert(){
    echo "Criando certificado SSL autoassinado..."
    mkdir -p /etc/xray/ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout $SSL_KEY -out $SSL_CERT \
      -subj "/CN=vpn.local"
}

# Criar configuração base do Xray
create_xray_config(){
    echo "Criando configuração base do Xray..."

    read -p "Digite a porta que deseja usar para todos os protocolos (exemplo: 443): " PORT

    if ! [[ "$PORT" =~ ^[0-9]+$ ]] ; then
       echo "Porta inválida!"
       exit 1
    fi

    cat > $XRAY_CONFIG <<EOF
{
  "inbounds": [
    {
      "port": $PORT,
      "protocol": "dokodemo-door",
      "settings": {
        "network": "tcp,udp",
        "timeout": 0,
        "followRedirect": true
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none"
      }
    },
    {
      "port": $PORT,
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "$SSL_CERT",
              "keyFile": "$SSL_KEY"
            }
          ]
        },
        "wsSettings": {
          "path": "/ws"
        }
      }
    },
    {
      "port": $PORT,
      "protocol": "vless",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "$SSL_CERT",
              "keyFile": "$SSL_KEY"
            }
          ]
        },
        "wsSettings": {
          "path": "/vless"
        }
      }
    },
    {
      "port": $PORT,
      "protocol": "trojan",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "$SSL_CERT",
              "keyFile": "$SSL_KEY"
            }
          ]
        }
      }
    },
    {
      "port": $PORT,
      "protocol": "shadowsocks",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "$SSL_CERT",
              "keyFile": "$SSL_KEY"
            }
          ]
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

    echo "Configuração criada na porta $PORT"
}

# Instalar BadVPN UDPGW
install_badvpn(){
    echo "Instalando BadVPN UDPGW..."
    git clone https://github.com/ambrop72/badvpn.git /opt/badvpn
    cd /opt/badvpn
    cmake -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
    make
    cp badvpn-udpgw /usr/local/bin/

    echo "Criando serviço systemd para BadVPN UDPGW..."
    cat > /etc/systemd/system/badvpn-udpgw.service <<EOF
[Unit]
Description=Badvpn UDPGW Service
After=network.target

[Service]
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:$BADVPN_UDPGW_PORT
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable badvpn-udpgw
    systemctl start badvpn-udpgw
}

# Criar banco de dados SQLite
create_database(){
    mkdir -p /opt/vpnmanager
    python3 - <<EOF
import sqlite3
conn = sqlite3.connect("$DB_PATH")
c = conn.cursor()
c.execute('''
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    login TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    uuid TEXT UNIQUE NOT NULL,
    created_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    data_limit_mb INTEGER,
    data_used_mb INTEGER DEFAULT 0
)
''')
conn.commit()
conn.close()
EOF
}

# Função para adicionar usuário via Python
add_user(){
    python3 - <<EOF
import sqlite3
import uuid
from datetime import datetime, timedelta
import json

db_path = "$DB_PATH"
config_path = "$XRAY_CONFIG"
login = "$1"
password = "$2"
days = int("$3")
limit = "$4"

expires_at = (datetime.utcnow() + timedelta(days=days)).isoformat()
user_uuid = str(uuid.uuid4())
data_limit_mb = int(limit) if limit.isdigit() else None

conn = sqlite3.connect(db_path)
c = conn.cursor()

try:
    c.execute("INSERT INTO users (login, password, uuid, created_at, expires_at, data_limit_mb) VALUES (?, ?, ?, ?, ?, ?)",
              (login, password, user_uuid, datetime.utcnow().isoformat(), expires_at, data_limit_mb))
    conn.commit()
except Exception as e:
    print("Erro ao adicionar usuário:", e)
    exit(1)

# Atualizar configuração Xray
with open(config_path, "r") as f:
    config = json.load(f)

clients_keys = ["vmess", "vless", "trojan", "shadowsocks"]
for proto in clients_keys:
    clients = []
    for inbound in config["inbounds"]:
        if inbound["protocol"] == proto:
            clients = inbound["settings"]["clients"]
            break

    new_client = {"id": user_uuid, "email": login}
    # Para shadowsocks precisa de um campo diferente
    if proto == "shadowsocks":
        new_client = {
            "password": password,
            "method": "aes-128-gcm",
            "email": login
        }
    elif proto == "trojan":
        new_client = {
            "password": password,
            "email": login
        }

    clients.append(new_client)

    # Atualiza a lista no config
    for inbound in config["inbounds"]:
        if inbound["protocol"] == proto:
            inbound["settings"]["clients"] = clients

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)

conn.close()
EOF

    systemctl restart $XRAY_SERVICE
    echo "Usuário $1 adicionado e Xray reiniciado."
}

# Função para listar usuários
list_users(){
    python3 - <<EOF
import sqlite3
conn = sqlite3.connect("$DB_PATH")
c = conn.cursor()
for row in c.execute("SELECT id, login, expires_at, data_limit_mb, data_used_mb FROM users"):
    print(f"ID: {row[0]} | Login: {row[1]} | Expira: {row[2]} | Limite MB: {row[3]} | Usado MB: {row[4]}")
conn.close()
EOF
}

# Função para deletar usuário
delete_user(){
    python3 - <<EOF
import sqlite3
import json

db_path = "$DB_PATH"
config_path = "$XRAY_CONFIG"
user_id = $1

conn = sqlite3.connect(db_path)
c = conn.cursor()

c.execute("SELECT uuid, login FROM users WHERE id = ?", (user_id,))
row = c.fetchone()
if not row:
    print("Usuário não encontrado!")
    exit(1)

user_uuid = row[0]

c.execute("DELETE FROM users WHERE id = ?", (user_id,))
conn.commit()

# Atualizar config Xray
with open(config_path, "r") as f:
    config = json.load(f)

for inbound in config["inbounds"]:
    clients = inbound["settings"].get("clients", [])
    inbound["settings"]["clients"] = [c for c in clients if c.get("id") != user_uuid and c.get("password") != user_uuid]

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)

conn.close()
print(f"Usuário {row[1]} deletado.")
EOF

    systemctl restart $XRAY_SERVICE
}

# Função para abrir porta firewall
open_port(){
    PORT=$1
    iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
    iptables -I INPUT -p udp --dport $PORT -j ACCEPT
    echo "Porta $PORT liberada no firewall."
}

# Função para mostrar portas abertas
show_ports(){
    iptables -L -n --line-numbers | grep -E "ACCEPT"
}

# Menu principal
menu(){
    while true; do
        CHOICE=$(dialog --clear --backtitle "VPN Manager" \
            --title "Menu Principal" \
            --menu "Escolha uma opção:" 15 55 8 \
            1 "Adicionar usuário" \
            2 "Listar usuários" \
            3 "Deletar usuário" \
            4 "Abrir porta no firewall" \
            5 "Mostrar portas abertas" \
            6 "Reiniciar serviços" \
            7 "Sair" 3>&1 1>&2 2>&3)

        clear
        case $CHOICE in
            1)
                read -p "Login: " LOGIN
                read -p "Senha: " PASS
                read -p "Dias de validade: " DIAS
                read -p "Limite de dados (MB, vazio para ilimitado): " LIMIT
                add_user "$LOGIN" "$PASS" "$DIAS" "$LIMIT"
                read -p "Pressione Enter para continuar..."
                ;;
            2)
                echo "Usuários cadastrados:"
                list_users
                read -p "Pressione Enter para continuar..."
                ;;
            3)
                read -p "ID do usuário para deletar: " UID
                delete_user "$UID"
                read -p "Pressione Enter para continuar..."
                ;;
            4)
                read -p "Porta para liberar: " PRT
                open_port "$PRT"
                read -p "Pressione Enter para continuar..."
                ;;
            5)
                echo "Portas abertas no firewall:"
                show_ports
                read -p "Pressione Enter para continuar..."
                ;;
            6)
                echo "Reiniciando serviços..."
                systemctl restart $XRAY_SERVICE
                systemctl restart $BADVPN_SERVICE
                echo "Serviços reiniciados."
                read -p "Pressione Enter para continuar..."
                ;;
            7)
                echo "Saindo..."
                exit 0
                ;;
            *)
                echo "Opção inválida."
                ;;
        esac
    done
}

# Execução principal
main(){
    install_dependencies
    install_xray
    create_ssl_cert
    create_xray_config
    install_badvpn
    create_database
    echo "Setup concluído! Iniciando menu..."
    menu
}

main
