#!/bin/bash
clear
fun_badvpn() {
echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\E[44;1;37m              BADVPN PRO 2               \E[0m"
echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
    if ps x | grep -w udpvpn | grep -v grep 1>/dev/null 2>/dev/null; then
        echo -e "\033[1;37mPORTAS BADVPN-UDPGW\033[1;37m: \033[1;32m$(netstat -nplt | grep 'badvpn-ud' | awk '{print $4}' | cut -d: -f2 | xargs)"
    else
        sleep 0.1
    fi
    if ps x | grep badvpn-tun2socks | grep -v grep 1>/dev/null 2>/dev/null; then
        portas_socks=$(ps x -o args | grep badvpn-tun2socks | grep -- '--socks-server-addr' | sed -n 's/.*--socks-server-addr \([0-9\.]*:[0-9]*\).*/\1/p' | xargs)
        echo -e "\033[1;37mPORTA BADVPN-TUN2SOCKS (SOCKS)\033[1;37m: \033[1;36m$portas_socks"
    fi
    var_sks1=$(ps x | grep "udpvpn"|grep -v grep > /dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")
    echo ""
    echo -e "\033[1;31m[\033[1;36m1\033[1;31m] \033[1;37m• \033[1;37mATIVAR BADVPN PRO 2 (PADRÃO 7300) $var_sks1 \033[0m"
    echo -e "\033[1;31m[\033[1;36m2\033[1;31m] \033[1;37m• \033[1;37mABRIR PORTA\033[0m"
    echo -e "\033[1;31m[\033[1;36m0\033[1;31m] \033[1;37m• \033[1;37mVOLTAR\033[0m"
    echo ""
    echo -ne "\033[1;32mO QUE DESEJA FAZER \033[1;37m?\033[1;37m "
    read resposta
    if [[ "$resposta" = '1' ]]; then
        if ps x | grep -w udpvpn | grep -v grep 1>/dev/null 2>/dev/null; then
            clear
echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\E[44;1;37m              BADVPN PRO 2               \E[0m"
echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
            echo ""
            fun_stopbad () {
                sleep 1
                for pidudpvpn in $(screen -ls | grep ".udpvpn" | awk {'print $1'}); do
                    screen -r -S "$pidudpvpn" -X quit
                done
                for pidtun2socks in $(screen -ls | grep ".tun2socks" | awk {'print $1'}); do
                    screen -r -S "$pidtun2socks" -X quit
                done
                [[ $(grep -wc "udpvpn" /etc/autostart) != '0' ]] && {
                    sed -i '/udpvpn/d' /etc/autostart
                }
                [[ $(grep -wc "tun2socks" /etc/autostart) != '0' ]] && {
                    sed -i '/tun2socks/d' /etc/autostart
                }
                sleep 1
                screen -wipe >/dev/null
            }
            echo -e "\033[1;32mDESATIVANDO O BADVPN\033[1;37m"
            echo ""
            fun_stopbad
            echo ""
            echo -e "\033[1;32mBADVPN DESATIVADO COM SUCESSO!\033[1;37m"
            sleep 3
            clear
            fun_badvpn
        else
            clear
            echo -e "\E[44;1;37m              BADVPN PRO 2               \E[0m"
            [ -f "/usr/local/bin/badvpn-udpgw" ]
            echo ""
            echo "INSTALANDO BADVPN AGUARDE... "
            fun_udpon () {
            
                screen -dmS udpvpn /bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 10000 --max-connections-for-client 1000
                
                if [[ ! -c /dev/net/tun ]]; then
                    mkdir -p /dev/net
                    mknod /dev/net/tun c 10 200
                    chmod 666 /dev/net/tun
                fi
                modprobe tun 2>/dev/null

                if [[ -e "/bin/badvpn-tun2socks" ]]; then
                    screen -dmS tun2socks /bin/badvpn-tun2socks --tundev tun0 --netif-ipaddr 10.0.0.2 --netif-netmask 255.255.255.0 --socks-server-addr 127.0.0.1:1080
                    sleep 1
                    if ps x | grep badvpn-tun2socks | grep -v grep > /dev/null; then
                        echo -e "\033[1;32mBADVPN-TUN2SOCKS ATIVADO COM SUCESSO!\033[1;37m"
                    else
                        echo -e "\033[1;31mFALHA AO ATIVAR BADVPN-TUN2SOCKS!\033[1;37m"
                    fi
                else
                    echo -e "\033[1;31mBINÁRIO badvpn-tun2socks NÃO ENCONTRADO!\033[1;37m"
                fi

                [[ $(grep -wc "udpvpn" /etc/autostart) = '0' ]] && {
                    echo -e "ps x | grep 'udpvpn' | grep -v 'grep' || screen -dmS udpvpn /bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 10000 --max-connections-for-client 1000" >> /etc/autostart
                } || {
                    sed -i '/udpvpn/d' /etc/autostart
                    echo -e "ps x | grep 'udpvpn' | grep -v 'grep' || screen -dmS udpvpn /bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 10000 --max-connections-for-client 1000" >> /etc/autostart
                }
                [[ $(grep -wc "tun2socks" /etc/autostart) = '0' ]] && {
                    echo -e "ps x | grep 'tun2socks' | grep -v 'grep' || screen -dmS tun2socks /bin/badvpn-tun2socks --tundev tun0 --netif-ipaddr 10.0.0.2 --netif-netmask 255.255.255.0 --socks-server-addr 127.0.0.1:1080" >> /etc/autostart
                } || {
                    sed -i '/tun2socks/d' /etc/autostart
                    echo -e "ps x | grep 'tun2socks' | grep -v 'grep' || screen -dmS tun2socks /bin/badvpn-tun2socks --tundev tun0 --netif-ipaddr 10.0.0.2 --netif-netmask 255.255.255.0 --socks-server-addr 127.0.0.1:1080" >> /etc/autostart
                }
                sleep 1
            }
            inst_udp () {
                [[ -e "/bin/badvpn-udpgw" ]] && [[ -e "/bin/badvpn-tun2socks" ]] && {
                    sleep 0.1
                } || {
                    cd $HOME
                    apt-get install dos2unix -y
                    wget -O badvpn-udpgw "https://www.dropbox.com/scl/fi/t9jiyfks29y8bg3kg1ey0/badvpn-udpgw?rlkey=aj3uvv0jaizk16h3dt5z4dat6&st=exapmkpi&dl=1"
                    mv -f $HOME/badvpn-udpgw /bin/badvpn-udpgw
                    chmod 777 /bin/badvpn-udpgw
                    wget -O badvpn-tun2socks "https://www.dropbox.com/scl/fi/nxpdtz9g1a1sxowx20ibr/badvpn-tun2socks?rlkey=ikjru9brkkbjb5ysrafe6igs4&st=oymcztz1&dl=1"
                    mv -f $HOME/badvpn-tun2socks /bin/badvpn-tun2socks
                    chmod 777 /bin/badvpn-tun2socks
                }
            }
            echo ""
            inst_udp
            fun_udpon
            echo ""
            echo -e "\033[1;32mBADVPN ATIVADO COM SUCESSO\033[1;37m"
            sleep 3
            clear
            fun_badvpn
        fi
    elif [[ "$resposta" = '2' ]]; then
        if ps x | grep -w udpvpn | grep -v grep 1>/dev/null 2>/dev/null; then
            clear
            echo -e "\E[44;1;37m            BADVPN             \E[0m"
            echo ""
            echo -ne "\033[1;32mQUAL PORTA DESEJA ULTILIZAR \033[1;37m?\033[1;37m: "
            read porta
            [[ -z "$porta" ]] && {
                echo ""
                echo -e "\033[1;31mPorta invalida!"
                sleep 2
                clear
                menu
            }
            echo ""
            echo -e "\033[1;32mINICIANDO O BADVPN NA PORTA \033[1;31m$porta\033[1;37m"
            echo ""
            fun_abrirptbad() {
                sleep 1
                screen -dmS udpvpn /bin/badvpn-udpgw --listen-addr 127.0.0.1:$porta --max-clients 10000 --max-connections-for-client 1000
                sleep 1
            }
            fun_abrirptbad
            echo ""
            echo -e "PORTA \033[1;32m$porta\033[1;37m ATIVADA COM SUCESSO"
            sleep 2
            clear
            fun_badvpn
        else
            clear
            echo -e "\033[1;31mFUNCAO INDISPONIVEL\n\n\033[1;37mATIVE O BADVPN PRIMEIRO !\033[1;37m"
            sleep 2
            fun_badvpn
        fi
    elif [[ "$resposta" = '0' ]]; then
        echo ""
        echo -e "\033[1;31mRetornando...\033[0m"
        sleep 1
        menu
    else
        echo ""
        echo -e "\033[1;31mOpcao invalida !\033[0m"
        sleep 1
        fun_badvpn
    fi
}
fun_badvpn