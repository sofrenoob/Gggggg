#!/bin/bash

CONFIG_DIR="/etc/hsproxy"
CONFIG_FILE="$CONFIG_DIR/config.json"
LOG_DIR="/var/log/hsproxy"
ACCESS_LOG="$LOG_DIR/access.log"
ERROR_LOG="$LOG_DIR/error.log"
RUN_PID="/var/run/hsproxy.pid"

function instalar_dependencias() {
    echo "[INFO] Instalando dependências..."
    apt update && apt install -y socat websocat jq curl lz4 net-tools iptables fail2ban
    mkdir -p "$CONFIG_DIR" "$LOG_DIR"
    touch "$ACCESS_LOG" "$ERROR_LOG"
    echo "[OK] Dependências instaladas e diretórios criados."
}

function salvar_config() {
    read -p "Porta local: " LOCAL_PORT
    echo "Adicione os hosts remotos (host:porta), separados por vírgula:"
    read -p "Ex: 1.1.1.1:80,2.2.2.2:443: " REMOTE_LIST
    echo "Modos disponíveis: tcp | websocket"
    read -p "Modo: " MODE
    read -p "Usar compressão? (s/n): " COMPRESS

    if [[ "$MODE" == "websocket" ]]; then
        read -p "Payload WebSocket (ex: GET / HTTP/1.1\r\nHost:example.com\r\n\r\n): " PAYLOAD
    else
        PAYLOAD=""
    fi

    cat <<EOF > "$CONFIG_FILE"
{
  "local_port": $LOCAL_PORT,
  "remote_list": "$REMOTE_LIST",
  "mode": "$MODE",
  "compress": "$COMPRESS",
  "payload": "$PAYLOAD"
}
EOF
    echo "[OK] Configuração salva."
}

function escolher_destino_disponivel() {
    IFS=',' read -ra HOSTS <<< "$(jq -r '.remote_list' "$CONFIG_FILE")"
    for H in "${HOSTS[@]}"; do
        HOST=$(echo "$H" | cut -d':' -f1)
        PORT=$(echo "$H" | cut -d':' -f2)
        nc -z -w2 $HOST $PORT && echo "$HOST:$PORT" && return
    done
    echo ""
}

function iniciar_proxy() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "[ERRO] Configure o proxy primeiro!"
        return
    fi

    LOCAL_PORT=$(jq -r '.local_port' "$CONFIG_FILE")
    MODE=$(jq -r '.mode' "$CONFIG_FILE")
    COMPRESS=$(jq -r '.compress' "$CONFIG_FILE")
    PAYLOAD=$(jq -r '.payload' "$CONFIG_FILE")

    DEST=$(escolher_destino_disponivel)
    if [[ -z "$DEST" ]]; then
        echo "[ERRO] Nenhum destino disponível." | tee -a "$ERROR_LOG"
        return
    fi

    REMOTE_HOST=$(echo "$DEST" | cut -d':' -f1)
    REMOTE_PORT=$(echo "$DEST" | cut -d':' -f2)

    echo "[INFO] Iniciando HSProxyPro na porta $LOCAL_PORT para $REMOTE_HOST:$REMOTE_PORT..." | tee -a "$ACCESS_LOG"

    case "$MODE" in
        "tcp")
            if [[ "$COMPRESS" == "s" ]]; then
                socat TCP-LISTEN:$LOCAL_PORT,reuseaddr,fork EXEC:"lz4 -d | socat - TCP:$REMOTE_HOST:$REMOTE_PORT" >> "$ACCESS_LOG" 2>> "$ERROR_LOG" &
            else
                socat TCP-LISTEN:$LOCAL_PORT,reuseaddr,fork TCP:$REMOTE_HOST:$REMOTE_PORT >> "$ACCESS_LOG" 2>> "$ERROR_LOG" &
            fi
            ;;
        "websocket")
            websocat -E -H="$PAYLOAD" ws-l:0.0.0.0:$LOCAL_PORT tcp:$REMOTE_HOST:$REMOTE_PORT >> "$ACCESS_LOG" 2>> "$ERROR_LOG" &
            ;;
        *)
            echo "[ERRO] Modo inválido" | tee -a "$ERROR_LOG"
            return
            ;;
    esac

    echo $! > "$RUN_PID"
    echo "[OK] Proxy iniciado com PID $(cat $RUN_PID)"
}

function parar_proxy() {
    if [[ -f "$RUN_PID" ]]; then
        kill "$(cat $RUN_PID)" && rm "$RUN_PID"
        echo "[OK] Proxy parado." | tee -a "$ACCESS_LOG"
    else
        echo "[ERRO] Proxy não está rodando." | tee -a "$ERROR_LOG"
    fi
}

function ver_status() {
    if [[ -f "$RUN_PID" ]]; then
        echo "[STATUS] Rodando com PID $(cat $RUN_PID)"
    else
        echo "[STATUS] Parado"
    fi
}

function ver_logs() {
    echo "Logs de acesso:"
    tail -n 20 "$ACCESS_LOG"
    echo ""
    echo "Logs de erro:"
    tail -n 20 "$ERROR_LOG"
}

function menu() {
    clear
    echo "========= HSProxy Pro v2 ========="
    echo "1) Instalar dependências"
    echo "2) Configurar conexão"
    echo "3) Iniciar proxy"
    echo "4) Parar proxy"
    echo "5) Ver status"
    echo "6) Ver logs"
    echo "7) Sair"
    echo "=================================="
    read -p "Escolha uma opção: " OP

    case $OP in
        1) instalar_dependencias ;;
        2) salvar_config ;;
        3) iniciar_proxy ;;
        4) parar_proxy ;;
        5) ver_status ;;
        6) ver_logs ;;
        7) exit 0 ;;
        *) echo "Opção inválida!" ;;
    esac
}

while true; do menu; done
