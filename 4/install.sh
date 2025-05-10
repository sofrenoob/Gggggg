#!/bin/bash

# Função para centralizar texto
center_text() {
    local text="$1"
    local width="$2"
    local len=${#text}
    local padding=$(( (width - len) / 2 ))
    printf "%${padding}s%s%${padding}s" "" "$text" ""
    # Ajuste para largura ímpar
    if [ $(( (width - len) % 2 )) -ne 0 ]; then
        printf " "
    fi
}

# Função para obter informações do sistema
get_system_info() {
    # Sistema operacional
    OS=$(uname -s)
    
    # Data e hora
    DATE=$(date +"%Y-%m-%d")
    TIME=$(date +"%H:%M:%S")
    
    # Informações da CPU
    if [[ "$OS" == "Linux" ]]; then
        CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d ':' -f2 | xargs)
        CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' | xargs)
        CORE_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2, $4, $6, $8}' | xargs)
    else
        CPU_MODEL="Unknown"
        CPU_USAGE="N/A"
        CORE_USAGE="N/A"
    fi
    
    # Informações de memória (em MB)
    if [[ "$OS" == "Linux" ]]; then
        MEM_TOTAL=$(free -m | grep Mem | awk '{print $2}')
        MEM_USED=$(free -m | grep Mem | awk '{print $3}')
        MEM_FREE=$(free -m | grep Mem | awk '{print $4}')
    else
        MEM_TOTAL="N/A"
        MEM_USED="N/A"
        MEM_FREE="N/A"
    fi
}

# Função para desenhar o menu
draw_menu() {
    clear
    tput cup 0 0
    get_system_info
    local title=$(figlet -f future -w 50 "CyberMenu" | sed 's/^/  /')
    local width=50

    # Borda superior
    echo -e "\e[96m╔════════════════════════════════════════════════════╗\e[0m"

    # Título
    while IFS= read -r line; do
        echo -e "\e[96m║\e[95m$(center_text "$line" $width)\e[96m║\e[0m"
    done <<< "$title"

    # Divisor
    echo -e "\e[96m╠════════════════════════════════════════════════════╣\e[0m"

    # Informações compactas
    echo -e "\e[96m║\e[92m$(center_text "OS: $OS  Data: $DATE" $width)\e[96m║\e[0m"
    echo -e "\e[96m║\e[92m$(center_text "CPU: ${CPU_MODEL:0:12}  Hora: $TIME" $width)\e[96m║\e[0m"
    echo -e "\e[96m║\e[92m$(center_text "CPU Total: $CPU_USAGE  Núcleos: ${CORE_USAGE:0:20}" $width)\e[96m║\e[0m"
    echo -e "\e[96m║\e[92m$(center_text "Mem: $MEM_TOTAL/$MEM_USED/$MEM_FREE MB" $width)\e[96m║\e[0m"

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

# Funções para cada opção do menu (exemplo)
start_system() {
    echo "Iniciando o sistema..."
    sleep 2
}

check_status() {
    echo "Verificando status do sistema..."
    uptime
    sleep 3
}

scan_network() {
    echo "Escaneando a rede..."
    if command -v nmap >/dev/null; then
        nmap -sn 192.168.1.0/24
    else
        echo "nmap não está instalado."
    fi
    sleep 3
}

backup_data() {
    echo "Realizando backup dos dados..."
    sleep 2
}

reboot_system() {
    echo "Reiniciando o sistema..."
    sleep 2
    # Descomente para reiniciar de verdade (requer permissões)
    # sudo reboot
}

configure_network() {
    echo "Configurando a rede..."
    ip addr show
    sleep 3
}

update_system() {
    echo "Atualizando o sistema..."
    if [[ -f /etc/debian_version ]]; then
        sudo apt update && sudo apt upgrade -y
    elif [[ -f /etc/redhat-release ]]; then
        sudo yum update -y
    else
        echo "Sistema não suportado para atualização automática."
    fi
    sleep 3
}

manage_users() {
    echo "Gerenciando usuários..."
    cat /etc/passwd | grep "/home" | cut -d: -f1
    sleep 3
}

monitor_resources() {
    echo "Monitorando recursos..."
    top -b -n 1 | head -n 10
    sleep 3
}

# Loop principal do menu
main() {
    while true; do
        draw_menu
        read option
        case $option in
            1) start_system ;;
            2) check_status ;;
            3) scan_network ;;
            4) backup_data ;;
            5) reboot_system ;;
            6) configure_network ;;
            7) update_system ;;
            8) manage_users ;;
            9) monitor_resources ;;
            10) echo "Saindo..."; exit 0 ;;
            *) echo "Opção inválida! Pressione Enter para continuar..."; read ;;
        esac
    done
}

# Verificar dependências
if ! command -v figlet >/dev/null; then
    echo "O comando 'figlet' não está instalado. Instale-o para o título do menu."
    echo "No Debian/Ubuntu: sudo apt install figlet"
    echo "No Red Hat/CentOS: sudo yum install figlet"
    exit 1
fi

# Iniciar o menu
main