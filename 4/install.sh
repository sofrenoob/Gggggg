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
    CPU=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
    [ -z "$CPU" ] && CPU="Unknown"
    DATE=$(date '+%Y-%m-%d')
    TIME=$(date '+%H:%M:%S')
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
    clear
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
    echo -e "\e[96m║\e[92m$(center_text "CPU: $CPU" $width)\e[96m║\e[0m"
    echo -e "\e[96m║\e[92m$(center_text "Data: $DATE" $width)\e[96m║\e[0m"
    echo -e "\e[96m║\e[92m$(center_text "Hora: $TIME" $width)\e[96m║\e[0m"
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

# Loop principal do menu
while true; do
    draw_menu
    read option

    case $option in
        1) echo "Iniciando sistema..."; sleep 2 ;;
        2) echo "Verificando status..."; sleep 2 ;;
        3) echo "Escaneando rede..."; sleep 2 ;;
        4) echo "Realizando backup..."; sleep 2 ;;
        5) echo "Reiniciando..."; sleep 2 ;;
        6) echo "Configurando rede..."; sleep 2 ;;
        7) echo "Atualizando sistema..."; sleep 2 ;;
        8) echo "Gerenciando usuários..."; sleep 2 ;;
        9) echo "Monitorando recursos..."; sleep 2 ;;
        10) echo "Saindo..."; exit 0 ;;
        *) echo "Opção inválida!"; sleep 2 ;;
    esac
done