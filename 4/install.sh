#!/bin/bash

# Verifica se o figlet está instalado
if ! command -v figlet &> /dev/null; then
    echo "Figlet não está instalado. Instale com 'sudo apt install figlet'."
    exit 1
fi

# Função para centralizar texto
center_text() {
    local text="$1"
    local width="$2"
    local len=${#text}
    local padding=$(( (width - len) / 2 ))
    printf "%${padding}s%s%${padding}s" "" "$text" ""
}

# Função para criar barra de progresso
progress_bar() {
    local percent=$1
    local max_bars=10
    local num_bars=$(echo "$percent / 10" | bc)
    local bar=""
    for ((i=0; i<max_bars; i++)); do
        if [ $i -lt $num_bars ]; then
            bar="$bar█"
        else
            bar="$bar "
        fi
    done
    echo "[$bar $percent%]"
}

# Função para obter informações do sistema
get_system_info() {
    OS=$(uname -s)
    CPU_MODEL=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
    [ -z "$CPU_MODEL" ] && CPU_MODEL="Unknown"
    DATE=$(date '+%Y-%m-%d')
    TIME=$(date '+%H:%M:%S')

    # Uso da CPU (total)
    CPU_USAGE=$(top -bn1 | grep '%Cpu(s)' | awk '{print 100 - $8}' | xargs printf "%.1f")

    # Memória (total, usada, livre em MB)
    MEM_INFO=$(free -m | grep Mem)
    MEM_TOTAL=$(echo "$MEM_INFO" | awk '{print $2}')
    MEM_USED=$(echo "$MEM_INFO" | awk '{print $3}')
    MEM_FREE=$(echo "$MEM_INFO" | awk '{print $4}')
}

# Função para desenhar o menu
draw_menu() {
    tput cup 0 0
    get_system_info
    local title=$(figlet -f standard -w 50 "CyberMenu" | sed 's/^/  /')
    local width=50
    local cpu_percent=$(echo "$CPU_USAGE" | tr -d '%')
    local mem_percent=$(echo "scale=1; $MEM_USED * 100 / $MEM_TOTAL" | bc)

    # Borda superior
    echo -e "\e[96m┌════════════════════════════════════════════════════┐\e[0m"

    # Título
    while IFS= read -r line; do
        echo -e "\e[96m│\e[95m$(center_text "$line" $width)\e[96m│\e[0m"
    done <<< "$title"

    # Divisor
    echo -e "\e[96m├════════════════════════════════════════════════════┤\e[0m"

    # Informações com barras
    echo -e "\e[96m│\e[94m$(center_text "OS: $OS  Data: $DATE  Hora: $TIME" $width)\e[96m│\e[0m"
    echo -e "\e[96m│\e[94m$(center_text "CPU: $CPU_USAGE% $(progress_bar $cpu_percent)  Mem: $(progress_bar $mem_percent)" $width)\e[96m│\e[0m"

    # Divisor
    echo -e "\e[96m├════════════════════════════════════════════════════┤\e[0m"

    # Opções em coluna única
    echo -e "\e[96m│\e[93m 1. Iniciar Sistema                                \e[96m│\e[0m"
    echo -e "\e[96m│\e[93m 2. Verificar Status                               \e[96m│\e[0m"
    echo -e "\e[96m│\e[93m 3. Escanear Rede                                  \e[96m│\e[0m"
    echo -e "\e[96m│\e[93m 4. Backup Dados                                   \e[96m│\e[0m"
    echo -e "\e[96m│\e[93m 5. Reiniciar                                      \e[96m│\e[0m"
    echo -e "\e[96m│\e[93m 6. Configurar Rede                                \e[96m│\e[0m"
    echo -e "\e[96m│\e[93m 7. Atualizar Sistema                              \e[96m│\e[0m"
    echo -e "\e[96m│\e[93m 8. Gerenciar Usuários                             \e[96m│\e[0m"
    echo -e "\e[96m│\e[93m 9. Monitorar Recursos                             \e[96m│\e[0m"
    echo -e "\e[96m│\e[93m 10. Sair                                          \e[96m│\e[0m"

    # Borda inferior
    echo -e "\e[96m└════════════════════════════════════════════════════┘\e[0m"
    echo -e "\e[96m[\e[95mOPÇÃO\e[96m]: \e[0m\c"
}

# Configura o terminal para permitir backspace
stty erase '^?'

# Inicializa o terminal
clear
tput civis  # Esconde o cursor para evitar tremulação

# Loop principal do menu
while true; do
    draw_menu
    # Lê entrada com timeout de 2 segundos e limpa buffer
    if read -r -t 2 -n 10000 option; then
        case $option in
            1) clear; echo -e "\nIniciando sistema..."; sleep 2 ;;
            2) clear; echo -e "\nVerificando status..."; sleep 2 ;;
            3) clear; echo -e "\nEscaneando rede..."; sleep 2 ;;
            4) clear; echo -e "\nRealizando backup..."; sleep 2 ;;
            5) clear; echo -e "\nReiniciando..."; sleep 2 ;;
            6) clear; echo -e "\nConfigurando rede..."; sleep 2 ;;
            7) clear; echo -e "\nAtualizando sistema..."; sleep 2 ;;
            8) clear; echo -e "\nGerenciando usuários..."; sleep 2 ;;
            9) clear; echo -e "\nMonitorando recursos..."; sleep 2 ;;
            10) clear; echo -e "\nSaindo..."; tput cnorm; exit 0 ;;
            *) clear; echo -e "\nOpção inválida! Tente novamente."; sleep 2 ;;
        esac
    else
        # Limpa buffer de entrada restante
        while read -r -t 0.1 -n 10000; do :; done
    fi
done