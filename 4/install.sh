#!/bin/bash

# Configura o terminal para backspace
stty -ixon
stty erase '^H'  # Mapeia backspace para Ctrl+H

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
    CORE_USAGE=$(grep 'cpu[0-9]' /proc/stat | head -n4 | awk '{usage=($2+$4)*100/($2+$4+$5); printf "%.1f%% ", usage}' | xargs)
    [ -z "$CORE_USAGE" ] && CORE_USAGE="N/A"

    # Memória (total, usada, livre em MB)
    MEM_INFO=$(free -m | grep Mem)
    MEM_TOTAL=$(echo "$MEM_INFO" | awk '{print $2}')
    MEM_USED=$(echo "$MEM_INFO" | awk '{print $3}')
    MEM_FREE=$(echo "$MEM_INFO" | awk '{print $4}')
}

# Função para desenhar o menu
draw_menu() {
    clear  # Limpa a tela para evitar sobreposição
    get_system_info
    local width=50

    # Borda superior
    echo -e "\e[96m╔════════════════════════════════════════════════════╗\e[0m"

    # Título simples
    echo -e "\e[96m║\e[95m$(center_text "Menu" $width)\e[96m║\e[0m"

    # Divisor
    echo -e "\e[96m╠════════════════════════════════════════════════════╣\e[0m"

    # Informações compactas
    echo -e "\e[96m║\e[92m$(center_text "OS: $OS  Data: $DATE" $width)\e[96m║\e[0m"
    echo -e "\e[96m║\e[92m$(center_text "CPU: ${CPU_MODEL:0:12}  Hora: $TIME" $width)\e[96m║\e[0m"
    echo -e "\e[96m║\e[92m$(center_text "CPU Total: $CPU_USAGE  Núcleos (1-4): ${CORE_USAGE:0:20}" $width)\e[96m║\e[0m"
    echo -e "\e[96m║\e[92m$(center_text "Mem: $MEM_TOTAL/$MEM_USED/$MEM_FREE MB (Total/Usada/Livre)" $width)\e[96m║\e[0m"

    # Divisor
    echo -e "\e[96m╠════════════════════════════════════════════════════╣\e[0m"

    # Opções
    echo -e "\e[96m║\e[93m  \e[1m1\e[0m\e[93m Iniciar Sistema   \e[1m6\e[0m\e[93m Configurar Rede    \e[96m║\e[0m"
    echo -e "\e[96m║\e[93m  \e[1m2\e[0m\e[93m Verificar Status  \e[1m7\e[0m\e[93m Atualizar Sistema  \e[96m║\e[0m"
    echo -e "\e[96m║\e[93m  \e[1m3\e[0m\e[93m Escanear Rede     \e[1m8\e[0m\e[93m Gerenciar Usuários \e[96m║\e[0m"
    echo -e "\e[96m║\e[93m  \e[1m4\e[0m\e[93m Backup Dados      \e[1m9\e[0m\e[93m Monitorar Recursos \e[96m║\e[0m"
    echo -e "\e[96m║\e[93m  \e[1m5\e[0m\e[93m Reiniciar        \e[1m10\e[0m\e[93m Sair              \e[96m║\e[0m"

    # Borda inferior
    echo -e "\e[96m╩════════════════════════════════════════════════════╩\e[0m"
    echo -e "\e[96m[\e[95mOPÇÃO\e[96m]: \e[0m\c"
}

# Inicializa o terminal
clear
tput civis  # Esconde o cursor para evitar tremulação

# Loop principal do menu
while true; do
    draw_menu
    # Lê entrada com timeout de 1 segundo
    if read -t 0 -r option; then
        case $option in
            1) echo -e "\nIniciando sistema..."; sleep 2 ;;
            2) echo -e "\nVerificando status..."; sleep 2 ;;
            3) echo -e "\nEscaneando rede..."; sleep 2 ;;
            4) echo -e "\nRealizando backup..."; sleep 2 ;;
            5) echo -e "\nReiniciando..."; sleep 2 ;;
            6) echo -e "\nConfigurando rede..."; sleep 2 ;;
            7) echo -e "\nAtualizando sistema..."; sleep 2 ;;
            8) echo -e "\nGerenciando usuários..."; sleep 2 ;;
            9) echo -e "\nMonitorando recursos..."; sleep 2 ;;
            10) echo -e "\nSaindo..."; tput cnorm; exit 0 ;;
            *) echo -e "\nOpção inválida!"; sleep 2 ;;
        esac
    fi
done