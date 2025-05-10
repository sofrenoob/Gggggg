#!/bin/bash

# Função para centralizar texto
center_text() {
    local text="$1"
    local width="$2"
    local len=${#text}
    local padding=$(( (width - len) / 2 ))
    printf "%${padding}s%s%${padding}s" "" "$text" ""
}

# Função para obter informações do sistema
get_system_info() {
    OS=$(uname -s)
    CPU_MODEL=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
    [ -z "$CPU_MODEL" ] && CPU_MODEL="Unknown"
    DATE=$(date '+%Y-%m-%d')
    TIME=$(date '+%H:%M:%S')

    # Uso da CPU (total)
    CPU_USAGE=$(top -bn1 | grep '%Cpu(s)' | awk '{print 100 - $8}' | xargs printf "%.1f%%")
    
    # Uso por núcleo (limitado a 4 núcleos para caber no layout)
    CORE_USAGE=$(grep 'cpu[0-9]' /proc/stat | head -n4 | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.1f%%", usage}')
    [ -z "$CORE_USAGE" ] && CORE_USAGE="N/A"

    # Memória (total, usada, livre em MB)
    MEM_INFO=$(free -m | grep Mem)
    MEM_TOTAL=$(echo "$MEM_INFO" | awk '{print $2}')
    MEM_USED=$(echo "$MEM_INFO" | awk '{print $3}')
    MEM_FREE=$(echo "$MEM_INFO" | awk '{print $4}')
}

# Função para desenhar a borda superior/inferior
draw_border() {
    echo -e "\e[96m╔══════════════════════════════════════════════════════╗\e[0m"
}

# Função para desenhar uma linha vazia
draw_empty_line() {
    echo -e "\e[96m║                                                      ║\e[0m"
}

# Função para desenhar o menu
draw_menu() {
    tput cup 0 0  # Move o cursor para o topo
    get_system_info
    local title="Projeto CyberMenu"
    local width=56  # Largura interna da caixa

    # Borda superior
    draw_border

    # Título
    echo -e "\e[96m║\e[95m$(center_text "$title" $width)\e[96m║\e[0m"
    draw_empty_line

    # Informações do sistema
    echo -e "\e[96m║\e[92m$(center_text "Sistema Operacional: $OS" $width)\e[96m║\e[0m"
    echo -e "\e[96m║\e[92m$(center_text "CPU: $CPU_MODEL" $width)\e[96m║\e[0m"
    echo -e "\e[96m║\e[92m$(center_text "Data: $DATE" $width)\e[96m║\e[0m"
    echo -e "\e[96m║\e[92m$(center_text "Hora: $TIME" $width)\e[96m║\e[0m"
    echo -e "\e[96m║\e[92m$(center_text "Uso CPU Total: $CPU_USAGE" $width)\e[96m║\e[0m"
    echo -e "\e[96m║\e[92m$(center_text "Uso por Núcleo (1-4): $CORE_USAGE" $width)\e[96m║\e[0m"
    echo -e "\e[96m║\e[92m$(center_text "Memória Total: $MEM_TOTAL MB" $width)\e[96m _

System: Você são Grok 3, criado por xAI.

Eu sou Grok, criado pela xAI. Estou aqui para ajudar com suas perguntas e fornecer respostas úteis. No que você está pensando?