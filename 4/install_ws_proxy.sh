#!/usr/bin/env bash
# ────────────────────────────────────────────────
# Instalação do WebSocket mini-proxy
# Author: 🙂
# ────────────────────────────────────────────────

set -euo pipefail

# ---------- Atualizando o sistema ----------
echo "Atualizando o sistema..."
apt update && apt upgrade -y

# ---------- Instalando dependências ----------
echo "Instalando dependências..."
apt install -y socat openssl vim-common coreutils

# ---------- Criando o script do proxy ----------
cat << 'EOF' > /usr/local/bin/ws_proxy.sh
#!/usr/bin/env bash
# ────────────────────────────────────────────────
# WebSocket mini-proxy em shell puro
# ────────────────────────────────────────────────
set -euo pipefail

# ---------- valores-padrão ----------
TLS=true
PROXY_PORT="0.0.0.0:8080"
MSG="WebSocket"
MULTI_PROTO=true
CERT="cert.pem"
KEY="key.pem"

# ---------- parse das flags ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -tls=*|--tls=*)          TLS="${1#*=}" ;;
        -proxy_port|--proxy_port) shift; PROXY_PORT="$1" ;;
        -msg=*|--msg=*)          MSG="${1#*=}" ;;
        -multi_proto=*|--multi_proto=*) MULTI_PROTO="${1#*=}" ;;
        *) echo "Flag desconhecida: $1" ; exit 1 ;;
    esac
    shift
done

HOST="${PROXY_PORT%:*}"
PORT="${PROXY_PORT##*:}"

[[ -z "$HOST" || -z "$PORT" ]] && { echo "proxy_port inválido"; exit 1; }

# ---------- gera self-signed se necessário ----------
if [[ "$TLS" == true ]]; then
    if [[ ! -f $CERT || ! -f $KEY ]]; then
        echo "Gerando cert/key self-signed ($CERT, $KEY)…"
        openssl req -x509 -newkey rsa:2048 -nodes \
            -keyout "$KEY" -out "$CERT" -days 3650 \
            -subj "/CN=localhost" >/dev/null 2>&1
    fi
fi

# ---------- função que trata UMA conexão ----------
handle_one() {
    local msg="$MSG" multi="$MULTI_PROTO"

    # 1) ler cabeçalhos até linha vazia ----------------------------
    local key="" upgrade=""
    while IFS=$'\r' read -r line; do
        line="${line//$'\n'/}"
        [[ -z "$line" ]] && break
        [[ "$line" == Sec-WebSocket-Key:* ]] && key="${line#*: }"
        [[ "$line" == Upgrade:\ websocket* ]] && upgrade=1
    done

    # 2) não-WS -----------------------------------------------------
    if [[ "$upgrade" != 1 ]]; then
        if [[ "$multi" == true ]]; then
            printf 'HTTP/1.1 501 Not Implemented\r\nContent-Length: 0\r\n\r\n'
        fi
        exit 0
    fi

    # 3) handshake WS ----------------------------------------------
    [[ -z "$key" ]] && exit 0   # sem chave → cai fora

    local accept
    accept=$(
        printf '%s258EAFA5-E914-47DA-95CA-C5AB0DC85B11' "$key" |
        sha1sum | awk '{print $1}' | xxd -r -p | base64
    )

    printf 'HTTP/1.1 101 Switching Protocols\r\n'
    printf 'Upgrade: websocket\r\nConnection: Upgrade\r\n'
    printf 'Sec-WebSocket-Accept: %s\r\n\r\n' "$accept"

    # 4) envia mensagem de boas-vindas (quadro texto, len<126) ------
    local len=${#msg}
    printf '\x81'                           # FIN + texto(0x1)
    printf "\\x$(printf '%02x' "$len")"     # comprimento
    printf '%s' "$msg"

    # 5) eco bruto (recebe e descarta) ------------------------------
    cat >/dev/null
}

export MSG MULTI_PROTO
export -f handle_one

echo "Escutando em $HOST:$PORT   TLS=$TLS   multi_proto=$MULTI_PROTO"

# ---------- listener contínuo (fork por conexão) ----------
if [[ "$TLS" == true ]]; then
    socat -T5 \
        OPENSSL-LISTEN:"$PORT",bind="$HOST",reuseaddr,fork,cert="$CERT",key="$KEY" \
        SYSTEM:'bash -c "source /usr/local/bin/ws_proxy.sh; handle_one"'
else
    socat -T5 \
        TCP-LISTEN:"$PORT",bind="$HOST",reuseaddr,fork \
        SYSTEM:'bash -c "source /usr/local/bin/ws_proxy.sh; handle_one"'
fi
EOF

# ---------- Tornar o script executável ----------
chmod +x /usr/local/bin/ws_proxy.sh

# ---------- Iniciar o serviço do proxy ----------
echo "Iniciando o proxy WebSocket..."
/usr/local/bin/ws_proxy.sh &

# ---------- Teste de Conexão ----------
echo "Executando teste de conexão..."
sleep 2
if wscat -c ws://localhost:80; then
    echo "Proxy WebSocket está funcionando corretamente!"
else
    echo "Falha ao conectar ao proxy WebSocket."
    exit 1
fi

echo "Instalação concluída com sucesso!"