#!/bin/bash
clear

# Menu Interativo Inteligente para Gerenciamento do BadVPN
# Inclui opção para ativar BadVPN (udpgw) e tun2socks juntos

# Funções auxiliares
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "\033[1;31mErro: Execute como root (use sudo)!\033[0m"
        sleep 2
        exit 1
    fi
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "\033[1;31mErro: $1 não está instalado. Deseja instalar $2? (s/n)\033[0m"
        read install_choice
        if [ "$install_choice" = "s" ]; then
            apt update
            apt install -y $2
        else
            echo -e "\033[1;31mSaindo... $1 é necessário.\033[0m"
            sleep 2
            exit 1
        fi
    fi
}

get_main_interface() {
    ip link show | grep -E '^[0-9]+: (eth|ens|enp|wlan)[0-9a-z]+' | awk '{print $2}' | cut -d: -f1 | head -n1
}

get_server_ip() {
    ip addr show $(get_main_interface) | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n1
}

suggest_tun_name() {
    last_tun=$(ip link show | grep -o 'tun[0-9]*' | sort -V | tail -n1)
    if [ -z "$last_tun" ]; then
        echo "tun0"
    else
        last_num=${last_tun//tun/}
        echo "tun$((last_num + 1))"
    fi
}

suggest_tun_ip() {
    last_tun=$(ip link show | grep -o 'tun[0-9]*' | sort -V | tail -n1)
    if [ -z "$last_tun" ]; then
        echo "10.0.0.1"
    else
        last_num=${last_tun//tun/}
        echo "10.0.$((last_num + 1)).1"
    fi
}

suggest_gateway_ip() {
    tun_ip=$1
    echo "${tun_ip%.*}.2"
}

# Função principal do menu
fun_badvpn() {
    clear
    echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\E[44;1;37m            GERENCIAR BADVPN             \E[0m"
    echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
    echo -e "\033[1;37mInterface de Rede: \033[1;32m$(get_main_interface)\033[0m"
    echo -e "\033[1;37mIP do Servidor: \033[1;32m$(get_server_ip)\033[0m"
    echo ""
    if ps x | grep -w badvpn-udpgw | grep -v grep >/dev/null 2>/dev/null; then
        echo -e "\033[1;37mPORTAS UDPGW: \033[1;32m$(netstat -nplt | grep 'badvpn-udpgw' | awk '{print $4}' | cut -d: -f2 | xargs)\033[0m"
    fi
    if ps x | grep -w badvpn-tun2socks | grep -v grep >/dev/null 2>/dev/null; then
        echo -e "\033[1;37mINTERFACES TUN: \033[1;32m$(ip link show | grep -o 'tun[0-9]*' | tr '\n' ' ')\033[0m"
    fi
    var_sks1=$(ps x | grep -w badvpn-udpgw | grep -v grep >/dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")
    var_sks2=$(ps x | grep -w badvpn-tun2socks | grep -v grep >/dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")
    var_sks3=$(ps x | grep -w danted | grep -v grep >/dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")
    echo ""
    echo -e "\033[1;31m[\033[1;36m1\033[1;31m] \033[1;37m• \033[1;37mATIVAR BADVPN + TUN2SOCKS\033[0m"
    echo -e "\033[1;31m[\033[1;36m2\033[1;31m] \033[1;37m• \033[1;37mATIVAR BADVPN (UDPGW) $var_sks1\033[0m"
    echo -e "\033[1;31m[\033[1;36m3\033[1;31m] \033[1;37m• \033[1;37mATIVAR TUN2SOCKS $var_sks2\033[0m"
    echo -e "\033[1;31m[\033[1;36m4\033[1;31m] \033[1;37m• \033[1;37mATIVAR DANTE (SOCKS5) $var_sks3\033[0m"
    echo -e "\033[1;31m[\033[1;36m5\033[1;31m] \033[1;37m• \033[1;37mDESATIVAR TODOS OS SERVIÇOS\033[0m"
    echo -e "\033[1;31m[\033[1;36m6\033[1;31m] \033[1;37m• \033[1;37mABRIR/FECHAR PORTAS (UFW)\033[0m"
    echo -e "\033[1;31m[\033[1;36m7\033[1;31m] \033[1;37m• \033[1;37mAJUSTAR LIMITES DE CONEXÕES\033[0m"
    echo -e "\033[1;31m[\033[1;36m8\033[1;31m] \033[1;37m• \033[1;37mMONITORAR TRÁFEGO (NLOAD)\033[0m"
    echo -e "\033[1;31m[\033[1;36m9\033[1;31m] \033[1;37m• \033[1;37mTESTAR CONECTIVIDADE SOCKS5\033[0m"
    echo -e "\033[1;31m[\033[1;36m10\033[1;31m] \033[1;37m• \033[1;37mATUALIZAR BADVPN\033[0m"
    echo -e "\033[1;31m[\033[1;36m11\033[1;31m] \033[1;37m• \033[1;37mCRIAR NOVA INTERFACE TUN\033[0m"
    echo -e "\033[1;31m[\033[1;36m12\033[1;31m] \033[1;37m• \033[1;37mREMOVER INTERFACE TUN\033[0m"
    echo -e "\033[1;31m[\033[1;36m13\033[1;31m] \033[1;37m• \033[1;37mVER LOGS\033[0m"
    echo -e "\033[1;31m[\033[1;36m0\033[1;31m] \033[1;37m• \033[1;37mVOLTAR\033[0m"
    echo ""
    echo -ne "\033[1;32mO QUE DESEJA FAZER? \033[1;37m"
    read resposta
    case $resposta in
        1)
            clear
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo -e "\E[44;1;37m            GERENCIAR BADVPN             \E[0m"
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo ""
            echo -e "\033[1;32mINICIANDO BADVPN (UDPGW) E TUN2SOCKS...\033[0m"
            # Verifica se udpgw já está ativo
            if ps x | grep -w badvpn-udpgw | grep -v grep >/dev/null 2>/dev/null; then
                echo -e "\033[1;37mUDPGW já está ativo na porta: \033[1;32m$(netstat -nplt | grep 'badvpn-udpgw' | awk '{print $4}' | cut -d: -f2 | xargs)\033[0m"
            else
                echo -ne "\033[1;32mDigite a porta UDPGW (padrão: 7300): \033[1;37m"
                read porta
                porta=${porta:-7300}
                screen -dmS udpvpn badvpn-udpgw --listen-addr 127.0.0.1:$porta --max-clients 9000 --max-connections-for-client 5
                echo -e "\033[1;32mBADVPN (UDPGW) ATIVADO NA PORTA $porta!\033[0m"
            fi
            # Verifica se tun2socks já está ativo
            if ps x | grep -w badvpn-tun2socks | grep -v grep >/dev/null 2>/dev/null; then
                echo -e "\033[1;37mTUN2SOCKS já está ativo nas interfaces: \033[1;32m$(ip link show | grep -o 'tun[0-9]*' | tr '\n' ' ')\033[0m"
            else
                suggested_tun=$(suggest_tun_name)
                suggested_ip=$(suggest_tun_ip)
                suggested_gateway=$(suggest_gateway_ip $suggested_ip)
                echo -e "\033[1;37mUma interface TUN é um túnel virtual para rotear tráfego da VPN.\033[0m"
                echo -ne "\033[1;32mDigite o nome da interface TUN (padrão: $suggested_tun): \033[1;37m"
                read tun_name
                tun_name=${tun_name:-$suggested_tun}
                echo -ne "\033[1;32mDigite o IP da interface (padrão: $suggested_ip): \033[1;37m"
                read tun_ip
                tun_ip=${tun_ip:-$suggested_ip}
                echo -ne "\033[1;32mDigite o IP do gateway (padrão: $suggested_gateway): \033[1;37m"
                read gateway_ip
                gateway_ip=${gateway_ip:-$suggested_gateway}
                ip tuntap add dev $tun_name mode tun user nobody
                ip addr add $tun_ip/24 dev $tun_name
                ip link set $tun_name up
                badvpn-tun2socks --tundev $tun_name --netif-ipaddr $gateway_ip \
                --netif-netmask 255.255.255.0 --socks-server-addr 127.0.0.1:1080 \
                --udpgw-remote-server-addr 127.0.0.1:$porta --loglevel none &
                ip route add default via $gateway_ip dev $tun_name metric 1
                echo -e "\033[1;32mTUN2SOCKS ATIVADO NA INTERFACE $tun_name!\033[0m"
            fi
            echo -e "\033[1;32mBADVPN E TUN2SOCKS INICIADOS COM SUCESSO!\033[0m"
            sleep 2
            fun_badvpn
            ;;
        2)
            if ps x | grep -w badvpn-udpgw | grep -v grep >/dev/null 2>/dev/null; then
                clear
                echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
                echo -e "\E[44;1;37m            GERENCIAR BADVPN             \E[0m"
                echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
                echo ""
                echo -e "\033[1;32mDESATIVANDO O BADVPN (UDPGW)...\033[0m"
                for pidudpvpn in $(screen -ls | grep ".udpvpn" | awk {'print $1'}); do
                    screen -r -S "$pidudpvpn" -X quit
                done
                screen -wipe >/dev/null
                systemctl stop badvpn-udpgw >/dev/null 2>&1
                echo -e "\033[1;32mBADVPN (UDPGW) DESATIVADO COM SUCESSO!\033[0m"
                sleep 2
                fun_badvpn
            else
                clear
                echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
                echo -e "\E[44;1;37m            GERENCIAR BADVPN             \E[0m"
                echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
                echo ""
                echo -e "\033[1;32mINICIANDO O BADVPN (UDPGW)...\033[0m"
                echo -ne "\033[1;32mDigite a porta UDPGW (padrão: 7300): \033[1;37m"
                read porta
                porta=${porta:-7300}
                screen -dmS udpvpn badvpn-udpgw --listen-addr 127.0.0.1:$porta --max-clients 9000 --max-connections-for-client 5
                echo -e "\033[1;32mBADVPN (UDPGW) ATIVADO NA PORTA $porta!\033[0m"
                sleep 2
                fun_badvpn
            fi
            ;;
        3)
            if ps x | grep -w badvpn-tun2socks | grep -v grep >/dev/null 2>/dev/null; then
                clear
                echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
                echo -e "\E[44;1;37m            GERENCIAR BADVPN             \E[0m"
                echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
                echo ""
                echo -e "\033[1;32mDESATIVANDO O TUN2SOCKS...\033[0m"
                systemctl stop badvpn-tun2socks >/dev/null 2>&1
                echo -e "\033[1;32mTUN2SOCKS DESATIVADO COM SUCESSO!\033[0m"
                sleep 2
                fun_badvpn
            else
                clear
                echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
                echo -e "\E[44;1;37m            GERENCIAR BADVPN             \E[0m"
                echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
                echo ""
                echo -e "\033[1;32mINICIANDO O TUN2SOCKS...\033[0m"
                suggested_tun=$(suggest_tun_name)
                suggested_ip=$(suggest_tun_ip)
                suggested_gateway=$(suggest_gateway_ip $suggested_ip)
                echo -e "\033[1;37mUma interface TUN é um túnel virtual para rotear tráfego da VPN.\033[0m"
                echo -ne "\033[1;32mDigite o nome da interface TUN (padrão: $suggested_tun): \033[1;37m"
                read tun_name
                tun_name=${tun_name:-$suggested_tun}
                echo -ne "\033[1;32mDigite o IP da interface (padrão: $suggested_ip): \033[1;37m"
                read tun_ip
                tun_ip=${tun_ip:-$suggested_ip}
                echo -ne "\033[1;32mDigite o IP do gateway (padrão: $suggested_gateway): \033[1;37m"
                read gateway_ip
                gateway_ip=${gateway_ip:-$suggested_gateway}
                ip tuntap add dev $tun_name mode tun user nobody
                ip addr add $tun_ip/24 dev $tun_name
                ip link set $tun_name up
                badvpn-tun2socks --tundev $tun_name --netif-ipaddr $gateway_ip \
                --netif-netmask 255.255.255.0 --socks-server-addr 127.0.0.1:1080 \
                --udpgw-remote-server-addr 127.0.0.1:7300 --loglevel none &
                ip route add default via $gateway_ip dev $tun_name metric 1
                echo -e "\033[1;32mTUN2SOCKS ATIVADO NA INTERFACE $tun_name!\033[0m"
                sleep 2
                fun_badvpn
            fi
            ;;
        4)
            if ps x | grep -w danted | grep -v grep >/dev/null 2>/dev/null; then
                clear
                echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
                echo -e "\E[44;1;37m            GERENCIAR BADVPN             \E[0m"
                echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
                echo ""
                echo -e "\033[1;32mDESATIVANDO O DANTE (SOCKS5)...\033[0m"
                systemctl stop danted
                echo -e "\033[1;32mDANTE DESATIVADO COM SUCESSO!\033[0m"
                sleep 2
                fun_badvpn
            else
                clear
                echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
                echo -e "\E[44;1;37m            GERENCIAR BADVPN             \E[0m"
                echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
                echo ""
                echo -e "\033[1;32mINICIANDO O DANTE (SOCKS5)...\033[0m"
                systemctl start danted
                echo -e "\033[1;32mDANTE ATIVADO COM SUCESSO!\033[0m"
                sleep 2
                fun_badvpn
            fi
            ;;
        5)
            clear
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo -e "\E[44;1;37m            GERENCIAR BADVPN             \E[0m"
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo ""
            echo -e "\033[1;32mDESATIVANDO TODOS OS SERVIÇOS...\033[0m"
            systemctl stop badvpn-udpgw >/dev/null 2>&1
            systemctl stop badvpn-tun2socks >/dev/null 2>&1
            systemctl stop danted
            for pidudpvpn in $(screen -ls | grep ".udpvpn" | awk {'print $1'}); do
                screen -r -S "$pidudpvpn" -X quit
            done
            screen -wipe >/dev/null
            echo -e "\033[1;32mTODOS OS SERVIÇOS DESATIVADOS!\033[0m"
            sleep 2
            fun_badvpn
            ;;
        6)
            clear
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo -e "\E[44;1;37m            GERENCIAR PORTAS (UFW)       \E[0m"
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo ""
            echo -e "\033[1;31m[\033[1;36m1\033[1;31m] \033[1;37m• ABRIR PORTA SOCKS (1080)\033[0m"
            echo -e "\033[1;31m[\033[1;36m2\033[1;31m] \033[1;37m• ABRIR PORTA SSH (22)\033[0m"
            echo -e "\033[1;31m[\033[1;36m3\033[1;31m] \033[1;37m• FECHAR PORTA ESPECÍFICA\033[0m"
            echo -e "\033[1;31m[\033[1;36m4\033[1;31m] \033[1;37m• LISTAR REGRAS UFW\033[0m"
            echo -e "\033[1;31m[\033[1;36m5\033[1;31m] \033[1;37m• ATIVAR UFW\033[0m"
            echo -e "\033[1;31m[\033[1;36m6\033[1;31m] \033[1;37m• DESATIVAR UFW\033[0m"
            echo -e "\033[1;31m[\033[1;36m0\033[1;31m] \033[1;37m• VOLTAR\033[0m"
            echo -ne "\033[1;32mO QUE DESEJA FAZER? \033[1;37m"
            read ufw_option
            case $ufw_option in
                1)
                    ufw allow 1080/tcp
                    echo -e "\033[1;32mPORTA 1080 (SOCKS) ABERTA!\033[0m"
                    sleep 2
                    fun_badvpn
                    ;;
                2)
                    ufw allow 22/tcp
                    echo -e "\033[1;32mPORTA 22 (SSH) ABERTA!\033[0m"
                    sleep 2
                    fun_badvpn
                    ;;
                3)
                    echo -ne "\033[1;32mDigite a porta para fechar: \033[1;37m"
                    read port
                    if [ -z "$port" ]; then
                        echo -e "\033[1;31mPorta inválida!\033[0m"
                        sleep 2
                    else
                        ufw delete allow $port
                        echo -e "\033[1;32mPORTA $port REMOVIDA!\033[0m"
                        sleep 2
                    fi
                    fun_badvpn
                    ;;
                4)
                    ufw status
                    read -p "Pressione Enter para continuar..."
                    fun_badvpn
                    ;;
                5)
                    ufw enable
                    echo -e "\033[1;32mUFW ATIVADO!\033[0m"
                    sleep 2
                    fun_badvpn
                    ;;
                6)
                    ufw disable
                    echo -e "\033[1;32mUFW DESATIVADO!\033[0m"
                    sleep 2
                    fun_badvpn
                    ;;
                0)
                    fun_badvpn
                    ;;
                *)
                    echo -e "\033[1;31mOpção inválida!\033[0m"
                    sleep 2
                    fun_badvpn
                    ;;
            esac
            ;;
        7)
            clear
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo -e "\E[44;1;37m       AJUSTAR LIMITES DE CONEXÕES       \E[0m"
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo ""
            echo -e "\033[1;37mSugestão: 10000 para suportar muitos usuários.\033[0m"
            echo -ne "\033[1;32mDigite o limite de conexões (padrão: 10000): \033[1;37m"
            read limit
            limit=${limit:-10000}
            echo "fs.file-max=$limit" >> /etc/sysctl.conf
            echo "* soft nofile $limit" >> /etc/security/limits.conf
            echo "* hard nofile $limit" >> /etc/security/limits.conf
            sysctl -p
            echo -e "\033[1;32mLIMITE AJUSTADO PARA $limit CONEXÕES!\033[0m"
            sleep 2
            fun_badvpn
            ;;
        8)
            clear
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo -e "\E[44;1;37m         MONITORAR TRÁFEGO (NLOAD)       \E[0m"
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo ""
            echo -e "\033[1;37mInterfaces TUN disponíveis: \033[1;32m$(ip link show | grep -o 'tun[0-9]*' | tr '\n' ' ')\033[0m"
            echo -ne "\033[1;32mDigite a interface para monitorar (padrão: tun0): \033[1;37m"
            read tun_monitor
            tun_monitor=${tun_monitor:-tun0}
            if ip link show $tun_monitor >/dev/null 2>&1; then
                echo -e "\033[1;32mMONITORANDO TRÁFEGO EM $tun_monitor (pressione q para sair)...\033[0m"
                nload $tun_monitor
            else
                echo -e "\033[1;31mInterface $tun_monitor não existe!\033[0m"
                sleep 2
            fi
            fun_badvpn
            ;;
        9)
            clear
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo -e "\E[44;1;37m       TESTAR CONECTIVIDADE SOCKS5       \E[0m"
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo ""
            echo -e "\033[1;32mTESTANDO SOCKS5 (127.0.0.1:1080)...\033[0m"
            server_ip=$(get_server_ip)
            echo -e "\033[1;37mIP do servidor detectado: \033[1;32m$server_ip\033[0m"
            curl --socks5 127.0.0.1:1080 http://ifconfig.me
            echo -e "\n\033[1;37mSe o IP acima é $server_ip, o SOCKS5 está funcionando.\033[0m"
            read -p "Pressione Enter para continuar..."
            fun_badvpn
            ;;
        10)
            clear
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo -e "\E[44;1;37m         ATUALIZAR BADVPN               \E[0m"
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo ""
            echo -ne "\033[1;32mDigite o caminho do BadVPN (padrão: /home/$USER/badvpn): \033[1;37m"
            read badvpn_path
            badvpn_path=${badvpn_path:-/home/$USER/badvpn}
            if [ ! -d "$badvpn_path" ]; then
                echo -e "\033[1;31mErro: Diretório $badvpn_path não encontrado!\033[0m"
                sleep 2
            else
                cd $badvpn_path
                git pull
                cd build
                cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_TUN2SOCKS=1 -DBUILD_UDPGW=1
                make -j$(nproc)
                make install
                systemctl restart badvpn-udpgw >/dev/null 2>&1
                systemctl restart badvpn-tun2socks >/dev/null 2>&1
                echo -e "\033[1;32mBADVPN ATUALIZADO COM SUCESSO!\033[0m"
                sleep 2
            fi
            fun_badvpn
            ;;
        11)
            clear
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo -e "\E[44;1;37m        CRIAR NOVA INTERFACE TUN         \E[0m"
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo ""
            suggested_tun=$(suggest_tun_name)
            suggested_ip=$(suggest_tun_ip)
            suggested_gateway=$(suggest_gateway_ip $suggested_ip)
            echo -e "\033[1;37mUma interface TUN é um túnel virtual para rotear tráfego da VPN.\033[0m"
            echo -ne "\033[1;32mDigite o nome da interface TUN (padrão: $suggested_tun): \033[1;37m"
            read tun_name
            tun_name=${tun_name:-$suggested_tun}
            echo -ne "\033[1;32mDigite o IP da interface (padrão: $suggested_ip): \033[1;37m"
            read tun_ip
            tun_ip=${tun_ip:-$suggested_ip}
            echo -ne "\033[1;32mDigite o IP do gateway (padrão: $suggested_gateway): \033[1;37m"
            read gateway_ip
            gateway_ip=${gateway_ip:-$suggested_gateway}
            ip tuntap add dev $tun_name mode tun user nobody
            ip addr add $tun_ip/24 dev $tun_name
            ip link set $tun_name up
            echo -ne "\033[1;32mIniciar tun2socks para $tun_name? (s/n): \033[1;37m"
            read start_tun
            if [ "$start_tun" = "s" ]; then
                badvpn-tun2socks --tundev $tun_name --netif-ipaddr $gateway_ip \
                --netif-netmask 255.255.255.0 --socks-server-addr 127.0.0.1:1080 \
                --udpgw-remote-server-addr 127.0.0.1:7300 --loglevel none &
                ip route add default via $gateway_ip dev $tun_name metric 1
                echo -e "\033[1;32mTUN2SOCKS ATIVADO NA INTERFACE $tun_name!\033[0m"
            else
                echo -e "\033[1;32mINTERFACE $tun_name CRIADA SEM TUN2SOCKS!\033[0m"
            fi
            sleep 2
            fun_badvpn
            ;;
        12)
            clear
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo -e "\E[44;1;37m        REMOVER INTERFACE TUN            \E[0m"
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo ""
            echo -e "\033[1;37mInterfaces TUN disponíveis: \033[1;32m$(ip link show | grep -o 'tun[0-9]*' | tr '\n' ' ')\033[0m"
            echo -ne "\033[1;32mDigite o nome da interface TUN para remover: \033[1;37m"
            read tun_name
            if ip link show $tun_name >/dev/null 2>&1; then
                ip tuntap del dev $tun_name mode tun
                echo -e "\033[1;32mINTERFACE $tun_name REMOVIDA!\033[0m"
            else
                echo -e "\033[1;31mErro: Interface $tun_name não existe!\033[0m"
            fi
            sleep 2
            fun_badvpn
            ;;
        13)
            clear
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo -e "\E[44;1;37m            VER LOGS                    \E[0m"
            echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo ""
            echo -e "\033[1;31m[\033[1;36m1\033[1;31m] \033[1;37m• LOGS DO DANTE\033[0m"
            echo -e "\033[1;31m[\033[1;36m2\033[1;31m] \033[1;37m• LOGS DO BADVPN-UDPGW\033[0m"
            echo -e "\033[1;31m[\033[1;36m3\033[1;31m] \033[1;37m• LOGS DO BADVPN-TUN2SOCKS\033[0m"
            echo -e "\033[1;31m[\033[1;36m0\033[1;31m] \033[1;37m• VOLTAR\033[0m"
            echo -ne "\033[1;32mO QUE DESEJA FAZER? \033[1;37m"
            read log_option
            case $log_option in
                1)
                    tail -n 50 /var/log/danted.log
                    read -p "Pressione Enter para continuar..."
                    fun_badvpn
                    ;;
                2)
                    journalctl -u badvpn-udpgw --no-pager -n 50
                    read -p "Pressione Enter para continuar..."
                    fun_badvpn
                    ;;
                3)
                    journalctl -u badvpn-tun2socks --no-pager -n 50
                    read -p "Pressione Enter para continuar..."
                    fun_badvpn
                    ;;
                0)
                    fun_badvpn
                    ;;
                *)
                    echo -e "\033[1;31mOpção inválida!\033[0m"
                    sleep 2
                    fun_badvpn
                    ;;
            esac
            ;;
        0)
            echo -e "\033[1;31mRetornando...\033[0m"
            sleep 1
            exit 0
            ;;
        *)
            echo -e "\033[1;31mOpção inválida!\033[0m"
            sleep 1
            fun_badvpn
            ;;
    esac
}

# Verificações iniciais
check_root
check_command ip iproute2
check_command systemctl systemd
check_command badvpn-tun2socks badvpn
check_command badvpn-udpgw badvpn
check_command danted dante-server
check_command curl curl
check_command nload nload
check_command ufw ufw
check_command screen screen

# Inicia o menu
fun_badvpn