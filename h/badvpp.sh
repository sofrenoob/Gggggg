#!/bin/bash

# -------------------------------------------------------------------
# Script de Gerenciamento do BadVPN Otimizado
# Mantém a aparência do script original, com otimizações de performance
# e melhores práticas do repositório oficial.
# -------------------------------------------------------------------

# --- Configurações --- 
# Endereço IP no qual o BadVPN irá escutar. Use 0.0.0.0 para todas as interfaces.
LISTEN_ADDR="127.0.0.1"

# Máximo de clientes conectados simultaneamente.
MAX_CLIENTS=2000

# Máximo de conexões por cliente.
MAX_CONNS_PER_CLIENT=5

# Buffer de envio do socket do cliente (em bytes). O valor de exemplo no 
# repositório oficial é 1048576 (1MB). Aumentar este valor pode melhorar
# a performance em redes com alta latência ou perda de pacotes.
CLIENT_SOCKET_SNDBUF=1048576

# Nível de log (0=erro, 1=aviso, 2=noticia, 3=info, 4=debug, 5=debug-verbose)
LOG_LEVEL=3

# Logger a ser usado (stdout, syslog)
LOGGER="syslog"

# Binário do BadVPN
BADVPN_BIN="/usr/local/bin/badvpn-udpgw"

# --- Cores --- 
VERMELHO=\'\033[1;31m\'
VERDE=\'\033[1;32m\'
AZUL=\'\033[1;34m\'
CYAN=\'\033[1;36m\'
BRANCO=\'\033[1;37m\'
NORMAL=\'\033[0m\'

# --- Funções Auxiliares ---

# Verifica se o BadVPN está instalado
check_badvpn_installed() {
    if [ ! -f "$BADVPN_BIN" ]; then
        clear
        echo -e "${VERMELHO}badvpn-udpgw não encontrado em $BADVPN_BIN${NORMAL}"
        echo -e "${BRANCO}Por favor, use a opção de instalar/atualizar o BadVPN no menu.${NORMAL}"
        sleep 4
        return 1
    fi
    return 0
}

# Instala/Atualiza o BadVPN a partir do código fonte
install_update_badvpn() {
    clear
    echo -e "${AZUL}Instalando/Atualizando o BadVPN...${NORMAL}"
    echo -e "${BRANCO}Isso irá baixar o código fonte e compilá-lo. Pode levar alguns minutos.${NORMAL}"
    
    # Instala dependências de compilação
    apt-get update > /dev/null 2>&1
    apt-get install -y git cmake build-essential > /dev/null 2>&1

    # Baixa o código fonte
    rm -rf /tmp/badvpn
    git clone https://github.com/ambrop72/badvpn.git /tmp/badvpn > /dev/null 2>&1

    # Compila e instala
    cd /tmp/badvpn
    mkdir build
    cd build
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 > /dev/null 2>&1
    make install > /dev/null 2>&1

    if [ -f "$BADVPN_BIN" ]; then
        echo -e "${VERDE}BadVPN instalado com sucesso em $BADVPN_BIN${NORMAL}"
    else
        echo -e "${VERMELHO}Falha na instalação do BadVPN.${NORMAL}"
    fi
    sleep 3
}

# Para todos os processos do BadVPN
stop_all_badvpn() {
    for pid in $(screen -ls | grep -o "[0-9]*\.udpvpn"); do
        screen -r -S "$pid" -X quit
    done
    # Remove do autostart
    sed -i '/badvpn-udpgw/d' /etc/autostart
    screen -wipe >/dev/null 2>&1
}

# --- Funções do Menu ---

# Ativa ou desativa o BadVPN na porta padrão 7300
toggle_badvpn_default() {
    if ! check_badvpn_installed; then return; fi

    if ps x | grep -w "$BADVPN_BIN" | grep -w "7300" | grep -v grep > /dev/null; then
        # Desativar
        clear
        echo -e "${BRANCO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NORMAL}"
        echo -e "\E[44;1;37m            GERENCIAR BADVPN             \E[0m"
        echo -e "${BRANCO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NORMAL}"
        echo ""
        echo -e "${VERDE}DESATIVANDO O BADVPN (Porta 7300)...${NORMAL}"
        
        pid=$(screen -ls | grep "udpvpn7300" | awk 	'{print $1}')
        if [[ ! -z "$pid" ]]; then
            screen -r -S "$pid" -X quit
        fi
        sed -i '/badvpn-udpgw.*7300/d' /etc/autostart
        screen -wipe >/dev/null 2>&1

        echo ""
        echo -e "${VERDE}BADVPN (Porta 7300) DESATIVADO COM SUCESSO!${NORMAL}"
        sleep 3
    else
        # Ativar
        clear
        echo -e "${VERDE}INICIANDO O BADVPN (Porta 7300)... ${NORMAL}\n"
        
        screen -dmS udpvpn7300 $BADVPN_BIN --listen-addr $LISTEN_ADDR:7300 --max-clients $MAX_CLIENTS --max-connections-for-client $MAX_CONNS_PER_CLIENT --client-socket-sndbuf $CLIENT_SOCKET_SNDBUF --loglevel $LOG_LEVEL --logger $LOGGER
        
        # Adiciona ao autostart
        sed -i '/badvpn-udpgw.*7300/d' /etc/autostart
        echo "screen -dmS udpvpn7300 $BADVPN_BIN --listen-addr $LISTEN_ADDR:7300 --max-clients $MAX_CLIENTS --max-connections-for-client $MAX_CONNS_PER_CLIENT --client-socket-sndbuf $CLIENT_SOCKET_SNDBUF --loglevel $LOG_LEVEL --logger $LOGGER" >> /etc/autostart

        echo ""
        echo -e "${VERDE}BADVPN ATIVADO COM SUCESSO NA PORTA 7300${NORMAL}"
        sleep 3
    fi
}

# Abre uma nova porta para o BadVPN
open_new_port() {
    if ! check_badvpn_installed; then return; fi

    clear
    echo -e "\E[44;1;37m            BADVPN             \E[0m"
    echo ""
    echo -ne "${VERDE}QUAL PORTA DESEJA UTILIZAR ${BRANCO}?${NORMAL}: "
    read porta

    if [[ -z "$porta" || ! "$porta" =~ ^[0-9]+$ || "$porta" -lt 1 || "$porta" -gt 65535 ]]; then
        echo ""
        echo -e "${VERMELHO}Porta inválida!${NORMAL}"
        sleep 2
        return
    fi

    if ps x | grep -w "$BADVPN_BIN" | grep -w "$porta" | grep -v grep > /dev/null; then
        echo ""
        echo -e "${VERMELHO}A porta $porta já está em uso pelo BadVPN.${NORMAL}"
        sleep 2
        return
    fi

    echo ""
    echo -e "${VERDE}INICIANDO O BADVPN NA PORTA ${VERMELHO}$porta${NORMAL}"
    echo ""
    
    screen -dmS udpvpn$porta $BADVPN_BIN --listen-addr $LISTEN_ADDR:$porta --max-clients $MAX_CLIENTS --max-connections-for-client $MAX_CONNS_PER_CLIENT --client-socket-sndbuf $CLIENT_SOCKET_SNDBUF --loglevel $LOG_LEVEL --logger $LOGGER
    
    # Adiciona ao autostart
    sed -i "/badvpn-udpgw.*$porta/d" /etc/autostart
    echo "screen -dmS udpvpn$porta $BADVPN_BIN --listen-addr $LISTEN_ADDR:$porta --max-clients $MAX_CLIENTS --max-connections-for-client $MAX_CONNS_PER_CLIENT --client-socket-sndbuf $CLIENT_SOCKET_SNDBUF --loglevel $LOG_LEVEL --logger $LOGGER" >> /etc/autostart

    echo ""
    echo -e "PORTA ${VERDE}$porta${NORMAL} ATIVADA COM SUCESSO"
    sleep 2
}

# Para uma porta específica do BadVPN
stop_specific_port() {
    clear
    echo -e "\E[44;1;37m            BADVPN             \E[0m"
    echo ""
    echo -ne "${VERDE}QUAL PORTA DESEJA PARAR ${BRANCO}?${NORMAL}: "
    read porta

    if [[ -z "$porta" || ! "$porta" =~ ^[0-9]+$ ]]; then
        echo ""
        echo -e "${VERMELHO}Porta inválida!${NORMAL}"
        sleep 2
        return
    fi

    if ! ps x | grep -w "$BADVPN_BIN" | grep -w "$porta" | grep -v grep > /dev/null; then
        echo ""
        echo -e "${VERMELHO}A porta $porta não está sendo usada pelo BadVPN.${NORMAL}"
        sleep 2
        return
    fi

    pid=$(screen -ls | grep "udpvpn$porta" | awk 	'{print $1}')
    if [[ ! -z "$pid" ]]; then
        screen -r -S "$pid" -X quit
    fi
    sed -i "/badvpn-udpgw.*$porta/d" /etc/autostart
    screen -wipe >/dev/null 2>&1

    echo ""
    echo -e "${VERDE}BADVPN (Porta $porta) DESATIVADO COM SUCESSO!${NORMAL}"
    sleep 3
}

# --- Menu Principal ---
main_menu() {
    while true; do
        clear
        echo -e "${BRANCO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NORMAL}"
        echo -e "\E[44;1;37m            GERENCIAR BADVPN             \E[0m"
        echo -e "${BRANCO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NORMAL}"
        echo ""
        
        portas_ativas=$(ps x | grep -w "$BADVPN_BIN" | grep -v grep | awk -F")[0-9]{1,5}" '{print $2}' | xargs)
        if [[ ! -z "$portas_ativas" ]]; then
            echo -e "${BRANCO}PORTAS ATIVAS: ${VERDE}$portas_ativas${NORMAL}"
        fi
        
        var_sks1=$(ps x | grep "$BADVPN_BIN" | grep -w "7300" | grep -v grep > /dev/null && echo -e "${VERDE}◉ " || echo -e "${VERMELHO}○ ")
        echo ""
        echo -e "${VERMELHO}[${CYAN}1${VERMELHO}] ${BRANCO}• ${BRANCO}ATIVAR/DESATIVAR BADVPN (PADRÃO 7300) $var_sks1${NORMAL}"
        echo -e "${VERMELHO}[${CYAN}2${VERMELHO}] ${BRANCO}• ${BRANCO}ABRIR PORTA ADICIONAL${NORMAL}"
        echo -e "${VERMELHO}[${CYAN}3${VERMELHO}] ${BRANCO}• ${BRANCO}PARAR PORTA ESPECÍFICA${NORMAL}"
        echo -e "${VERMELHO}[${CYAN}4${VERMELHO}] ${BRANCO}• ${BRANCO}PARAR TODOS OS BADVPN${NORMAL}"
        echo -e "${VERMELHO}[${CYAN}5${VERMELHO}] ${BRANCO}• ${BRANCO}INSTALAR/ATUALIZAR BADVPN${NORMAL}"
        echo -e "${VERMELHO}[${CYAN}0${VERMELHO}] ${BRANCO}• ${BRANCO}SAIR${NORMAL}"
        echo ""
        echo -ne "${VERDE}O QUE DESEJA FAZER ${BRANCO}?${NORMAL} "
        read resposta

        case "$resposta" in
            1) toggle_badvpn_default ;;
            2) open_new_port ;;
            3) stop_specific_port ;;
            4) stop_all_badvpn ;;
            5) install_update_badvpn ;;
            0) break ;;
            *) echo "" ; echo -e "${VERMELHO}Opção inválida!${NORMAL}" ; sleep 1 ;;
        esac
    done
    clear
}

# --- Início do Script ---
main_menu


