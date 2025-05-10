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
    CORE_USAGE=$(grep 'cpu[0-9]' /proc/stat | head -n4 | awk '{usage=($2+$4)*100/($2+$4+$5); printf "%.1f%% ", usage}' | xargs)
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
    echo -e "\e[96m║\e[92m$(center_text "Memória Total: $MEM_TOTAL MB" $width)\e[96m║\e[0m"
    echo -e "\e[96m║\e[92m$(center_text "Memória Usada: $MEM_USED MB" $width)\e[96m║\e[0m"
    echo -e "\e[96m║\e[92m$(center_text "Memória Livre: $MEM_FREE MB" $width)\e[96m║\e[0m"
    draw_empty_line

    # Opções do menu (5 de cada lado)
    echo -e "\e[96m║\e[93m  1. Iniciar Sistema      6. Configurar Rede     \e[96m║\e[0m"
    echo -e "\e[96m║\e[93m  2. Verificar Status     7. Atualizar Sistema   \e[96m║\e[0m"
    echo -e "\e[96m║\e[93m  3. Escanear Rede       8. Gerenciar Usuários  \e[96m║\e[0m"
    echo -e "\e[96m║\e[93m  4. Backup Dados        9. Monitorar Recursos  \e[96m║\e[0m"
    echo -e "\e[96m║\e[93m  5. Reiniciar          10. Sair              \e[96m║\e[0m"
    draw_empty_line

    # Rodapé
    draw_border
    echo -e "\e[96m[\e[95mOPÇÃO\e[96m]: \e[0m\c"
}

# Inicializa o terminal
clear
tput civis  # Esconde o cursor para evitar tremulação

# Loop principal do menu
while true; do
    draw_menu
    # Lê entrada com timeout de 1 segundo
    if read -t 1 -r option; then
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