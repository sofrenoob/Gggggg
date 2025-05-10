#!/data/data/com.termux/files/usr/bin/bash

# Arquivos
OUTPUT_FILE="$HOME/proxies_funcionais.txt"
LOG_FILE="$HOME/scan_log.txt"
WHOIS_CACHE="$HOME/whois_cache.txt"
SCAN_OUTPUT="$HOME/scan_output.txt"

# Configurações padrão
PORTS="80,8080,443"
TIMEOUT=5
MAX_PROCESSES=10
SCAN_RANGE="100"  # Incremento em blocos de IPs (ex.: de 100.x.x.x até 200.x.x.x)
FILTER_OPERATORS="yes"

# Ranges de operadoras (atualize com base na sua região)
OPERATORS=(
    "Vivo:177.104.0.0/14,187.0.0.0/12"
    "TIM:186.192.0.0/16,189.0.0.0/12"
    "Claro:177.0.0.0/12,191.248.0.0/14"
)

# Função para verificar dependências
check_dependencies() {
    for cmd in curl whois nmap; do
        if ! command -v "$cmd" >/dev/null; then
            echo "Instalando $cmd..."
            pkg install "$cmd" -y || { echo "Erro ao instalar $cmd"; exit 1; }
        fi
    done
}

# Função para verificar rede da operadora
check_network() {
    if ip link show | grep -q "rmnet0"; then
        echo "Usando rede da operadora (dados móveis)." | tee -a "$LOG_FILE"
    else
        echo "Erro: Ative os dados móveis e desative o Wi-Fi." | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Função para obter IP da operadora
get_operator_ip() {
    LOCAL_IP=$(ip addr show | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | grep -v '127.0.0.1' | head -n 1)
    if [ -z "$LOCAL_IP" ]; then
        echo "Erro: Não foi possível obter o IP da operadora." | tee -a "$LOG_FILE"
        exit 1
    fi
    echo "IP da operadora: $LOCAL_IP" | tee -a "$LOG_FILE"
}

# Função para definir intervalo de escaneamento
set_scan_range() {
    # Extrai o primeiro octeto do IP (ex.: 100 de 100.x.x.x)
    BASE_IP=$(echo "$LOCAL_IP" | cut -d. -f1)
    START_IP="$BASE_IP.0.0.0"
    END_IP=$((BASE_IP + SCAN_RANGE))
    END_IP="$END_IP.0.0.0"
    IP_RANGE="$START_IP-$END_IP"
    echo "Intervalo de escaneamento: $IP_RANGE" | tee -a "$LOG_FILE"
}

# Função para monitoramento de sistema (simplificada)
monitor_system() {
    mem_usage=$(free -m | awk '/Mem:/ {print $3/$2 * 100}')
    echo "Memória: ${mem_usage}%"
}

# Função para verificar operadora
check_operator() {
    local ip=$1
    if grep -q "^$ip:" "$WHOIS_CACHE"; then
        grep "^$ip:" "$WHOIS_CACHE" | cut -d: -f2
        return
    fi

    for op in "${OPERATORS[@]}"; do
        name=$(echo "$op" | cut -d: -f1)
        ranges=$(echo "$op" | cut -d: -f2 | tr ',' ' ')
        for range in $ranges; do
            if ipcalc -r "$ip" "$range" >/dev/null 2>&1; then
                echo "$name" | tee -a "$WHOIS_CACHE"
                return
            fi
        done
    done

    whois_result=$(whois "$ip" | grep -i 'Vivo\|TIM\|Claro' | head -n 1 | awk '{print $NF}')
    echo "${whois_result:-Desconhecida}" | tee -a "$WHOIS_CACHE"
}

# Função para testar um proxy
test_proxy() {
    local ip=$1
    local port=$2

    response=$(curl -s -o /dev/null -w "%{http_code}" --proxy "http://$ip:$port" \
        --connect-timeout "$TIMEOUT" -X GET "http://httpbin.org/get" 2>/dev/null)
    if [ "$response" = "200" ]; then
        operator=$(check_operator "$ip")
        if [ "$FILTER_OPERATORS" = "yes" ] && [ "$operator" = "Desconhecida" ]; then
            return
        fi
        echo "$ip:$port - Status 200 OK ($operator)" | tee -a "$LOG_FILE"
        echo "{\"ip\":\"$ip\",\"port\":$port,\"status\":200,\"operator\":\"$operator\"}" >> "$OUTPUT_FILE"
    fi
}

# Função para escanear IPs com nmap
run_scan() {
    check_network
    get_operator_ip
    set_scan_range
    echo "Escaneando $IP_RANGE nas portas $PORTS..." | tee -a "$LOG_FILE"
    nmap -p"$PORTS" --open -oG "$SCAN_OUTPUT" "$IP_RANGE" | tee -a "$LOG_FILE"

    if [ ! -s "$SCAN_OUTPUT" ]; then
        echo "Nenhuma porta aberta encontrada!" | tee -a "$LOG_FILE"
        exit 1
    fi

    echo "Testando proxies encontrados..." | tee -a "$LOG_FILE"
    grep "open" "$SCAN_OUTPUT" | grep -oP '\d+\.\d+\.\d+\.\d+.*\d+' | \
        while read -r line; do
            ip=$(echo "$line" | awk '{print $1}')
            port=$(echo "$line" | grep -oP '\d+/open' | cut -d/ -f1)
            test_proxy "$ip" "$port" &
            [ $(jobs | wc -l) -ge "$MAX_PROCESSES" ] && wait
        done
    wait

    if [ -s "$OUTPUT_FILE" ]; then
        gzip -f "$OUTPUT_FILE"
        echo "Resultados salvos em $OUTPUT_FILE.gz" | tee -a "$LOG_FILE"
    fi
    echo "Escaneamento concluído!" | tee -a "$LOG_FILE"
}

# Menu interativo
show_menu() {
    clear
    echo "====================================="
    monitor_system
    echo "====================================="
    echo "Turbo Proxy Scanner (Termux)"
    echo "====================================="
    echo "1. Portas ($PORTS)"
    echo "2. Timeout ($TIMEOUT)"
    echo "3. Processos simultâneos ($MAX_PROCESSES)"
    echo "4. Intervalo de escaneamento (até +$SCAN_RANGE blocos)"
    echo "5. Filtrar operadoras ($FILTER_OPERATORS)"
    echo "6. Iniciar escaneamento"
    echo "7. Sair"
    echo "====================================="
    echo -n "Opção: "
    read option
}

# Instala dependências
check_dependencies

# Loop do menu
> "$LOG_FILE"
> "$WHOIS_CACHE"
while true; do
    show_menu
    case $option in
        1)
            echo -n "Novas portas (ex.: 80,8080,443): "
            read PORTS
            ;;
        2)
            echo -n "Timeout (segundos): "
            read TIMEOUT
            ;;
        3)
            echo -n "Processos simultâneos: "
            read MAX_PROCESSES
            ;;
        4)
            echo -n "Incremento de blocos (ex.: 100 para +100.x.x.x): "
            read SCAN_RANGE
            ;;
        5)
            echo -n "Filtrar operadoras (yes/no): "
            read FILTER_OPERATORS
            ;;
        6)
            run_scan
            echo "Pressione Enter para continuar..."
            read
            ;;
        7)
            echo "Saindo..."
            exit 0
            ;;
        *)
            echo "Opção inválida!" | tee -a "$LOG_FILE"
            sleep 1
            ;;
    esac
done