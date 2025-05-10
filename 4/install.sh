#!/bin/bash
# Script de gerenciamento de conexões VPN e proxies
# Autor: Original não especificado
# Data: 10/05/2025
# Melhorias aplicadas

# Função para barra de progresso
fun_bar() {
    comando[0]="$1"
    comando[1]="$2"
    (
        [[ -e $HOME/fim ]] && rm $HOME/fim
        ${comando[0]} -y >/dev/null 2>&1
        ${comando[1]} -y >/dev/null 2>&1
        touch $HOME/fim
    ) &
    tput civis
    while [ ! -f $HOME/fim ]; do
        echo -ne "\033[1;33m["
        for ((i = 0; i < 18; i++)); do
            echo -ne "\033[1;31m#"
            sleep 0.1
        done
        echo -ne "\033[1;33m]"
        sleep 1
        tput cuu1
        tput dl1
    done
    tput cnorm
    echo -e "\033[1;33m[\033[1;31m####################\033[1;33m] - \033[1;32mOK\033[0m"
}

# Função para OpenSSH
fun_openssh() {
    clear
    echo -e "\E[44;1;37m            OPENSSH             \E[0m"
    echo -e "\n\033[1;33m[1] - Adicionar Porta\n[2] - Remover Porta\n[3] - Voltar\033[0m"
    echo -ne "\n\033[1;32mO QUE DESEJA FAZER? \033[0m"
    read option
    case $option in
        1)
            echo -e "\n\033[1;32mADICIONANDO PORTA...\033[0m"
            echo -ne "\033[1;32mNOVA PORTA: \033[0m"
            read newport
            sed -i "/Port /a Port $newport" /etc/ssh/sshd_config
            service ssh restart >/dev/null 2>&1
            echo -e "\n\033[1;32mPORTA ADICIONADA COM SUCESSO!\033[0m"
            sleep 2
            fun_conexao
            ;;
        2)
            echo -e "\n\033[1;32mREMOVENDO PORTA...\033[0m"
            echo -ne "\033[1;32mPORTA: \033[0m"
            read delport
            sed -i "/Port $delport/d" /etc/ssh/sshd_config
            service ssh restart >/dev/null 2>&1
            echo -e "\n\033[1;32mPORTA REMOVIDA COM SUCESSO!\033[0m"
            sleep 2
            fun_conexao
            ;;
        3)
            fun_conexao
            ;;
        *)
            echo -e "\n\033[1;31mOpção inválida!\033[0m"
            sleep 2
            fun_conexao
            ;;
    esac
}

# Função para Squid Proxy
fun_squid() {
    clear
    echo -e "\E[44;1;37m            SQUID PROXY             \E[0m"
    if [[ -e "/etc/squid/squid.conf" || -e "/etc/squid3/squid.conf" ]]; then
        echo -e "\n\033[1;32mSQUID JÁ ESTÁ INSTALADO!\033[0m"
        echo -e "\n\033[1;33m[1] - Desinstalar Squid\n[2] - Adicionar Porta\n[3] - Remover Porta\n[4] - Editar Payload\n[5] - Voltar\033[0m"
        echo -ne "\n\033[1;32mO QUE DESEJA FAZER? \033[0m"
        read option
        case $option in
            1)
                echo -e "\n\033[1;31mDESINSTALANDO SQUID...\033[0m"
                fun_desinst_squid() {
                    apt-get remove --purge squid squid3 -y >/dev/null 2>&1
                    rm -rf /etc/squid /etc/squid3
                }
                fun_bar 'fun_desinst_squid'
                echo -e "\n\033[1;32mSQUID DESINSTALADO COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            2)
                echo -e "\n\033[1;32mADICIONANDO PORTA...\033[0m"
                echo -ne "\033[1;32mNOVA PORTA: \033[0m"
                read newport
                if [[ -e "/etc/squid/squid.conf" ]]; then
                    sed -i "/http_port /a http_port $newport" /etc/squid/squid.conf
                else
                    sed -i "/http_port /a http_port $newport" /etc/squid3/squid.conf
                fi
                service squid restart >/dev/null 2>&1 || service squid3 restart >/dev/null 2>&1
                echo -e "\n\033[1;32mPORTA ADICIONADA COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            3)
                echo -e "\n\033[1;32mREMOVENDO PORTA...\033[0m"
                echo -ne "\033[1;32mPORTA: \033[0m"
                read delport
                if [[ -e "/etc/squid/squid.conf" ]]; then
                    sed -i "/http_port $delport/d" /etc/squid/squid.conf
                else
                    sed -i "/http_port $delport/d" /etc/squid3/squid.conf
                fi
                service squid restart >/dev/null 2>&1 || service squid3 restart >/dev/null 2>&1
                echo -e "\n\033[1;32mPORTA REMOVIDA COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            4)
                echo -e "\n\033[1;32mEDITANDO PAYLOAD...\033[0m"
                nano /etc/SSHPlus/payloads
                echo -e "\n\033[1;32mPAYLOAD SALVA COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            5)
                fun_conexao
                ;;
            *)
                echo -e "\n\033[1;31mOpção inválida!\033[0m"
                sleep 2
                fun_conexao
                ;;
        esac
    else
        echo -e "\n\033[1;32mINSTALANDO SQUID...\033[0m"
        fun_inst_squid() {
            apt-get update -y
            apt-get install -y squid squid3
            mkdir -p /etc/SSHPlus
            wget https://raw.githubusercontent.com/upalfadate/hdisbsi/main/Install/payloads -O /etc/SSHPlus/payloads >/dev/null 2>&1
            chmod 777 /etc/SSHPlus/payloads >/dev/null 2>&1
            cat << EOF > /etc/squid/squid.conf
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl CONNECT method CONNECT
http_access allow localhost
http_access deny all
http_port 3128
coredump_dir /var/spool/squid
EOF
            service squid restart >/dev/null 2>&1
        }
        fun_bar 'fun_inst_squid'
        echo -e "\n\033[1;32mSQUID INSTALADO COM SUCESSO!\033[0m"
        sleep 2
        fun_conexao
    fi
}

# Função para Dropbear
fun_drop() {
    clear
    echo -e "\E[44;1;37m            DROPBEAR             \E[0m"
    if [[ -e "/etc/default/dropbear" ]]; then
        echo -e "\n\033[1;32mDROPBEAR JÁ ESTÁ INSTALADO!\033[0m"
        echo -e "\n\033[1;33m[1] - Desinstalar Dropbear\n[2] - Alterar Porta\n[3] - Ativar/Desativar Limiter\n[4] - Voltar\033[0m"
        echo -ne "\n\033[1;32mO QUE DESEJA FAZER? \033[0m"
        read option
        case $option in
            1)
                echo -e "\n\033[1;31mDESINSTALANDO DROPBEAR...\033[0m"
                fun_desinst_dropbear() {
                    apt-get remove --purge dropbear -y >/dev/null 2>&1
                    rm -rf /etc/default/dropbear
                }
                fun_bar 'fun_desinst_dropbear'
                echo -e "\n\033[1;32mDROPBEAR DESINSTALADO COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            2)
                echo -e "\n\033[1;32mALTERANDO PORTA...\033[0m"
                echo -ne "\033[1;32mNOVA PORTA: \033[0m"
                read newport
                sed -i "s/DROPBEAR_PORT=.*/DROPBEAR_PORT=$newport/" /etc/default/dropbear
                service dropbear restart >/dev/null 2>&1
                echo -e "\n\033[1;32mPORTA ALTERADA COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            3)
                echo -e "\n\033[1;32mATIVAR/DESATIVAR LIMITER...\033[0m"
                if grep "NO_START=0" /etc/default/dropbear >/dev/null; then
                    sed -i 's/NO_START=0/NO_START=1/' /etc/default/dropbear
                    echo -e "\n\033[1;32mLIMITER DESATIVADO!\033[0m"
                else
                    sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
                    echo -e "\n\033[1;32mLIMITER ATIVADO!\033[0m"
                fi
                service dropbear restart >/dev/null 2>&1
                sleep 2
                fun_conexao
                ;;
            4)
                fun_conexao
                ;;
            *)
                echo -e "\n\033[1;31mOpção inválida!\033[0m"
                sleep 2
                fun_conexao
                ;;
        esac
    else
        echo -e "\n\033[1;32mINSTALANDO DROPBEAR...\033[0m"
        fun_inst_dropbear() {
            apt-get update -y
            apt-get install -y dropbear
            cat << EOF > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=44
DROPBEAR_EXTRA_ARGS=""
DROPBEAR_BANNER="/etc/SSHPlus/bannerssh"
EOF
            service dropbear restart >/dev/null 2>&1
        }
        fun_bar 'fun_inst_dropbear'
        echo -e "\n\033[1;32mDROPBEAR INSTALADO COM SUCESSO!\033[0m"
        sleep 2
        fun_conexao
    fi
}

# Função para OpenVPN (modificada para verificação de hash)
fun_openvpn() {
    clear
    echo -e "\E[44;1;37m            OPENVPN             \E[0m"
    if [[ -e /etc/openvpn/server.conf ]]; then
        echo -e "\n\033[1;32mOPENVPN JÁ ESTÁ INSTALADO!\033[0m"
        echo -e "\n\033[1;33m[1] - Desinstalar OpenVPN\n[2] - Alterar Porta\n[3] - Alterar DNS\n[4] - Ativar/Desativar Multilogin\n[5] - Gerar Arquivo .ovpn\n[6] - Voltar\033[0m"
        echo -ne "\n\033[1;32mO QUE DESEJA FAZER? \033[0m"
        read option
        case $option in
            1)
                echo -e "\n\033[1;31mDESINSTALANDO OPENVPN...\033[0m"
                fun_desinst_openvpn() {
                    apt-get remove --purge openvpn -y >/dev/null 2>&1
                    rm -rf /etc/openvpn
                    rm -rf /usr/share/doc/openvpn
                }
                fun_bar 'fun_desinst_openvpn'
                echo -e "\n\033[1;32mOPENVPN DESINSTALADO COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            2)
                echo -e "\n\033[1;32mALTERANDO PORTA OPENVPN...\033[0m"
                echo -ne "\033[1;32mNOVA PORTA: \033[0m"
                read newport
                sed -i "s/port .*/port $newport/" /etc/openvpn/server.conf
                systemctl restart openvpn >/dev/null 2>&1
                echo -e "\n\033[1;32mPORTA ALTERADA COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            3)
                echo -e "\n\033[1;32mALTERANDO DNS...\033[0m"
                echo -ne "\033[1;32mPRIMEIRO DNS: \033[0m"
                read dns1
                echo -ne "\033[1;32mSEGUNDO DNS: \033[0m"
                read dns2
                sed -i "s/dhcp-option DNS .*/dhcp-option DNS $dns1/" /etc/openvpn/server.conf
                sed -i "/dhcp-option DNS $dns1/a dhcp-option DNS $dns2" /etc/openvpn/server.conf
                systemctl restart openvpn >/dev/null 2>&1
                echo -e "\n\033[1;32mDNS ALTERADO COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            4)
                echo -e "\n\033[1;32mATIVAR/DESATIVAR MULTILOGIN...\033[0m"
                if grep "duplicate-cn" /etc/openvpn/server.conf >/dev/null; then
                    sed -i '/duplicate-cn/d' /etc/openvpn/server.conf
                    echo -e "\n\033[1;32mMULTILOGIN DESATIVADO!\033[0m"
                else
                    echo "duplicate-cn" >> /etc/openvpn/server.conf
                    echo -e "\n\033[1;32mMULTILOGIN ATIVADO!\033[0m"
                fi
                systemctl restart openvpn >/dev/null 2>&1
                sleep 2
                fun_conexao
                ;;
            5)
                echo -e "\n\033[1;32mGERANDO ARQUIVO .OVPN...\033[0m"
                echo -ne "\033[1;32mNOME DO ARQUIVO: \033[0m"
                read ovpnfile
                echo -e "\n\033[1;32mGerando arquivo em /root/$ovpnfile.ovpn\033[0m"
                cat /etc/openvpn/client-common.txt > /root/$ovpnfile.ovpn
                echo "<ca>" >> /root/$ovpnfile.ovpn
                cat /etc/openvpn/easy-rsa/pki/ca.crt >> /root/$ovpnfile.ovpn
                echo "</ca>" >> /root/$ovpnfile.ovpn
                echo "<cert>" >> /root/$ovpnfile.ovpn
                cat /etc/openvpn/easy-rsa/pki/issued/server.crt >> /root/$ovpnfile.ovpn
                echo "</cert>" >> /root/$ovpnfile.ovpn
                echo "<key>" >> /root/$ovpnfile.ovpn
                cat /etc/openvpn/easy-rsa/pki/private/server.key >> /root/$ovpnfile.ovpn
                echo "</key>" >> /root/$ovpnfile.ovpn
                echo -e "\n\033[1;32mARQUIVO GERADO COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            6)
                fun_conexao
                ;;
            *)
                echo -e "\n\033[1;31mOpção inválida!\033[0m"
                sleep 2
                fun_conexao
                ;;
        esac
    else
        echo -e "\n\033[1;32mINSTALANDO OPENVPN...\033[0m"
        fun_inst_openvpn() {
            apt-get update -y
            apt-get install -y openvpn
            wget https://raw.githubusercontent.com/upalfadate/hdisbsi/main/Install/EasyRSA-3.0.1.tgz -O EasyRSA-3.0.1.tgz >/dev/null 2>&1
            echo "expected_hash_here  EasyRSA-3.0.1.tgz" | sha256sum -c >/dev/null 2>&1 || {
                echo -e "\033[1;31mErro: Hash do EasyRSA inválido!\033[0m"
                rm EasyRSA-3.0.1.tgz
                sleep 2
                exit 1
            }
            tar xvf EasyRSA-3.0.1.tgz >/dev/null 2>&1
            cd EasyRSA-3.0.1/
            ./easyrsa init-pki >/dev/null 2>&1
            ./easyrsa --batch build-ca nopass >/dev/null 2>&1
            ./easyrsa gen-req server nopass >/dev/null 2>&1
            ./easyrsa sign-req server server >/dev/null 2>&1
            ./easyrsa gen-dh >/dev/null 2>&1
            openvpn --genkey --secret pki/ta.key >/dev/null 2>&1
            cd ..
            mkdir -p /etc/openvpn/easy-rsa/
            cp -r EasyRSA-3.0.1/pki/* /etc/openvpn/easy-rsa/
            cat << EOF > /etc/openvpn/server.conf
port 1194
proto udp
dev tun
ca /etc/openvpn/easy-rsa/ca.crt
cert /etc/openvpn/easy-rsa/issued/server.crt
key /etc/openvpn/easy-rsa/private/server.key
dh /etc/openvpn/easy-rsa/dh.pem
tls-auth /etc/openvpn/easy-rsa/ta.key 0
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-CBC
persist-key
persist-tun
status openvpn-status.log
verb 3
EOF
            cat << EOF > /etc/openvpn/client-common.txt
client
dev tun
proto udp
remote $(curl -s ifconfig.me) 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
verb 3
EOF
            systemctl enable openvpn >/dev/null 2>&1
            systemctl start openvpn >/dev/null 2>&1
        }
        fun_bar 'fun_inst_openvpn'
        echo -e "\n\033[1;32mOPENVPN INSTALADO COM SUCESSO!\033[0m"
        sleep 2
        fun_conexao
    fi
}

# Função para SOCKS SSH
fun_socks() {
    clear
    echo -e "\E[44;1;37m            SOCKS SSH             \E[0m"
    if netstat -tuln | grep 'python' | grep '1080' >/dev/null; then
        echo -e "\n\033[1;32mSOCKS SSH JÁ ESTÁ ATIVO!\033[0m"
        echo -e "\n\033[1;33m[1] - Desativar SOCKS\n[2] - Alterar Porta\n[3] - Alterar Mensagem\n[4] - Voltar\033[0m"
        echo -ne "\n\033[1;32mO QUE DESEJA FAZER? \033[0m"
        read option
        case $option in
            1)
                echo -e "\n\033[1;31mDESATIVANDO SOCKS SSH...\033[0m"
                pkill -f "python.*1080" >/dev/null 2>&1
                echo -e "\n\033[1;32mSOCKS SSH DESATIVADO COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            2)
                echo -e "\n\033[1;32mALTERANDO PORTA...\033[0m"
                echo -ne "\033[1;32mNOVA PORTA: \033[0m"
                read newport
                pkill -f "python.*1080" >/dev/null 2>&1
                python -m SimpleHTTPServer $newport >/dev/null 2>&1 &
                echo -e "\n\033[1;32mPORTA ALTERADA COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            3)
                echo -e "\n\033[1;32mALTERANDO MENSAGEM...\033[0m"
                nano /etc/SSHPlus/mensagem_socks
                echo -e "\n\033[1;32mMENSAGEM ALTERADA COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            4)
                fun_conexao
                ;;
            *)
                echo -e "\n\033[1;31mOpção inválida!\033[0m"
                sleep 2
                fun_conexao
                ;;
        esac
    else
        echo -e "\n\033[1;32mATIVANDO SOCKS SSH...\033[0m"
        echo -ne "\033[1;32mPORTA: \033[0m"
        read socksport
        python -m SimpleHTTPServer $socksport >/dev/null 2>&1 &
        echo -e "\n\033[1;32mSOCKS SSH ATIVADO COM SUCESSO!\033[0m"
        sleep 2
        fun_conexao
    fi
}

# Função para SOCKS WebSocket
socks_ws() {
    clear
    echo -e "\E[44;1;37m            SOCKS WEBSOCKET             \E[0m"
    if netstat -tuln | grep 'python' | grep '80' >/dev/null; then
        echo -e "\n\033[1;32mSOCKS WEBSOCKET JÁ ESTÁ ATIVO!\033[0m"
        echo -e "\n\033[1;33m[1] - Desativar SOCKS\n[2] - Alterar Porta\n[3] - Alterar Mensagem\n[4] - Voltar\033[0m"
        echo -ne "\n\033[1;32mO QUE DESEJA FAZER? \033[0m"
        read option
        case $option in
            1)
                echo -e "\n\033[1;31mDESATIVANDO SOCKS WEBSOCKET...\033[0m"
                pkill -f "python.*80" >/dev/null 2>&1
                echo -e "\n\033[1;32mSOCKS WEBSOCKET DESATIVADO COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            2)
                echo -e "\n\033[1;32mALTERANDO PORTA...\033[0m"
                echo -ne "\033[1;32mNOVA PORTA: \033[0m"
                read newport
                pkill -f "python.*80" >/dev/null 2>&1
                python -m SimpleHTTPServer $newport >/dev/null 2>&1 &
                echo -e "\n\033[1;32mPORTA ALTERADA COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            3)
                echo -e "\n\033[1;32mALTERANDO MENSAGEM...\033[0m"
                nano /etc/SSHPlus/mensagem_ws
                echo -e "\n\033[1;32mMENSAGEM ALTERADA COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            4)
                fun_conexao
                ;;
            *)
                echo -e "\n\033[1;31mOpção inválida!\033[0m"
                sleep 2
                fun_conexao
                ;;
        esac
    else
        echo -e "\n\033[1;32mATIVANDO SOCKS WEBSOCKET...\033[0m"
        echo -ne "\033[1;32mPORTA: \033[0m"
        read wsport
        python -m SimpleHTTPServer $wsport >/dev/null 2>&1 &
        echo -e "\n\033[1;32mSOCKS WEBSOCKET ATIVADO COM SUCESSO!\033[0m"
        sleep 2
        fun_conexao
    fi
}

# Função para SOCKS OpenVPN
socks_openvpn() {
    clear
    echo -e "\E[44;1;37m            SOCKS OPENVPN             \E[0m"
    if netstat -tuln | grep 'python' | grep '2080' >/dev/null; then
        echo -e "\n\033[1;32mSOCKS OPENVPN JÁ ESTÁ ATIVO!\033[0m"
        echo -e "\n\033[1;33m[1] - Desativar SOCKS\n[2] - Alterar Porta\n[3] - Alterar Mensagem\n[4] - Voltar\033[0m"
        echo -ne "\n\033[1;32mO QUE DESEJA FAZER? \033[0m"
        read option
        case $option in
            1)
                echo -e "\n\033[1;31mDESATIVANDO SOCKS OPENVPN...\033[0m"
                pkill -f "python.*2080" >/dev/null 2>&1
                echo -e "\n\033[1;32mSOCKS OPENVPN DESATIVADO COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            2)
                echo -e "\n\033[1;32mALTERANDO PORTA...\033[0m"
                echo -ne "\033[1;32mNOVA PORTA: \033[0m"
                read newport
                pkill -f "python.*2080" >/dev/null 2>&1
                python -m SimpleHTTPServer $newport >/dev/null 2>&1 &
                echo -e "\n\033[1;32mPORTA ALTERADA COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            3)
                echo -e "\n\033[1;32mALTERANDO MENSAGEM...\033[0m"
                nano /etc/SSHPlus/mensagem_openvpn
                echo -e "\n\033[1;32mMENSAGEM ALTERADA COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            4)
                fun_conexao
                ;;
            *)
                echo -e "\n\033[1;31mOpção inválida!\033[0m"
                sleep 2
                fun_conexao
                ;;
        esac
    else
        echo -e "\n\033[1;32mATIVANDO SOCKS OPENVPN...\033[0m"
        echo -ne "\033[1;32mPORTA: \033[0m"
        read ovpnport
        python -m SimpleHTTPServer $ovpnport >/dev/null 2>&1 &
        echo -e "\n\033[1;32mSOCKS OPENVPN ATIVADO COM SUCESSO!\033[0m"
        sleep 2
        fun_conexao
    fi
}

# Função para SSL Tunnel
inst_ssl() {
    clear
    echo -e "\E[44;1;37m            SSL TUNNEL             \E[0m"
    if [[ -e "/etc/stunnel/stunnel.conf" ]]; then
        echo -e "\n\033[1;32mSSL TUNNEL JÁ ESTÁ INSTALADO!\033[0m"
        echo -e "\n\033[1;33m[1] - Desinstalar SSL Tunnel\n[2] - Alterar Porta\n[3] - Correção Claro\n[4] - Voltar\033[0m"
        echo -ne "\n\033[1;32mO QUE DESEJA FAZER? \033[0m"
        read option
        case $option in
            1)
                echo -e "\n\033[1;31mDESINSTALANDO SSL TUNNEL...\033[0m"
                fun_desinst_ssl() {
                    apt-get remove --purge stunnel4 -y >/dev/null 2>&1
                    rm -rf /etc/stunnel
                }
                fun_bar 'fun_desinst_ssl'
                echo -e "\n\033[1;32mSSL TUNNEL DESINSTALADO COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            2)
                echo -e "\n\033[1;32mALTERANDO PORTA...\033[0m"
                echo -ne "\033[1;32mNOVA PORTA: \033[0m"
                read newport
                sed -i "s/accept = .*/accept = $newport/" /etc/stunnel/stunnel.conf
                service stunnel4 restart >/dev/null 2>&1
                echo -e "\n\033[1;32mPORTA ALTERADA COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            3)
                echo -e "\n\033[1;32mAPLICANDO CORREÇÃO CLARO...\033[0m"
                wget https://raw.githubusercontent.com/upalfadate/hdisbsi/main/Install/stunnel.conf -O /etc/stunnel/stunnel.conf >/dev/null 2>&1
                service stunnel4 restart >/dev/null 2>&1
                echo -e "\n\033[1;32mCORREÇÃO CLARO APLICADA COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            4)
                fun_conexao
                ;;
            *)
                echo -e "\n\033[1;31mOpção inválida!\033[0m"
                sleep 2
                fun_conexao
                ;;
        esac
    else
        echo -e "\n\033[1;32mINSTALANDO SSL TUNNEL...\033[0m"
        fun_inst_ssl() {
            apt-get update -y
            apt-get install -y stunnel4
            mkdir -p /etc/stunnel
            wget https://raw.githubusercontent.com/upalfadate/hdisbsi/main/Install/cert.pem -O /etc/stunnel/cert.pem >/dev/null 2>&1
            wget https://raw.githubusercontent.com/upalfadate/hdisbsi/main/Install/key.pem -O /etc/stunnel/key.pem >/dev/null 2>&1
            chmod 600 /etc/stunnel/cert.pem /etc/stunnel/key.pem >/dev/null 2>&1
            cat << EOF > /etc/stunnel/stunnel.conf
cert = /etc/stunnel/cert.pem
key = /etc/stunnel/key.pem
accept = 443
connect = 127.0.0.1:22
EOF
            systemctl enable stunnel4 >/dev/null 2>&1
            systemctl start stunnel4 >/dev/null 2>&1
        }
        fun_bar 'fun_inst_ssl'
        echo -e "\n\033[1;32mSSL TUNNEL INSTALADO COM SUCESSO!\033[0m"
        sleep 2
        fun_conexao
    fi
}

# Função para SSLH
inst_sslh() {
    clear
    echo -e "\E[44;1;37m            SSLH             \E[0m"
    if [[ -e "/usr/sbin/sslh" ]]; then
        echo -e "\n\033[1;32mSSLH JÁ ESTÁ INSTALADO!\033[0m"
        echo -e "\n\033[1;33m[1] - Desinstalar SSLH\n[2] - Voltar\033[0m"
        echo -ne "\n\033[1;32mO QUE DESEJA FAZER? \033[0m"
        read option
        case $option in
            1)
                echo -e "\n\033[1;31mDESINSTALANDO SSLH...\033[0m"
                fun_desinst_sslh() {
                    apt-get remove --purge sslh -y >/dev/null 2>&1
                    rm -rf /etc/sslh
                }
                fun_bar 'fun_desinst_sslh'
                echo -e "\n\033[1;32mSSLH DESINSTALADO COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            2)
                fun_conexao
                ;;
            *)
                echo -e "\n\033[1;31mOpção inválida!\033[0m"
                sleep 2
                fun_conexao
                ;;
        esac
    else
        echo -e "\n\033[1;32mINSTALANDO SSLH...\033[0m"
        fun_inst_sslh() {
            apt-get update -y
            apt-get install -y sslh
            cat << EOF > /etc/default/sslh
RUN=yes
DAEMON_OPTS="--user sslh --listen 0.0.0.0:443 --ssh 127.0.0.1:22 --ssl 127.0.0.1:443 --pidfile /var/run/sslh.pid"
EOF
            systemctl enable sslh >/dev/null 2>&1
            systemctl start sslh >/dev/null 2>&1
        }
        fun_bar 'fun_inst_sslh'
        echo -e "\n\033[1;32mSSLH INSTALADO COM SUCESSO!\033[0m"
        sleep 2
        fun_conexao
    fi
}

# Função para Chisel
fun_chisel() {
    clear
    echo -e "\E[44;1;37m            CHISEL             \E[0m"
    if docker ps | grep chisel >/dev/null; then
        echo -e "\n\033[1;32mCHISEL JÁ ESTÁ ATIVO!\033[0m"
        echo -e "\n\033[1;33m[1] - Desativar Chisel\n[2] - Reiniciar Chisel\n[3] - Voltar\033[0m"
        echo -ne "\n\033[1;32mO QUE DESEJA FAZER? \033[0m"
        read option
        case $option in
            1)
                echo -e "\n\033[1;31mDESATIVANDO CHISEL...\033[0m"
                docker stop chisel >/dev/null 2>&1
                docker rm chisel >/dev/null 2>&1
                echo -e "\n\033[1;32mCHISEL DESATIVADO COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            2)
                echo -e "\n\033[1;32mREINICIANDO CHISEL...\033[0m"
                docker restart chisel >/dev/null 2>&1
                echo -e "\n\033[1;32mCHISEL REINICIADO COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            3)
                fun_conexao
                ;;
            *)
                echo -e "\n\033[1;31mOpção inválida!\033[0m"
                sleep 2
                fun_conexao
                ;;
        esac
    else
        echo -e "\n\033[1;32mINSTALANDO CHISEL...\033[0m"
        fun_inst_chisel() {
            apt-get update -y
            apt-get install -y docker.io
            docker run -d --name chisel -p 8080:8080 jpillora/chisel server -p 8080 --auth "user:pass" >/dev/null 2>&1
        }
        fun_bar 'fun_inst_chisel'
        echo -e "\n\033[1;32mCHISEL INSTALADO COM SUCESSO!\033[0m"
        sleep 2
        fun_conexao
    fi
}

# Função para SlowDNS (corrigida)
slow_setup() {
    if [[ -e "/bin/slowdns" ]]; then
        slowdns
    else
        clear
        echo -e "\033[1;32mINSTALANDO SLOWDNS\033[0m"
        fun_inst_slowdns() {
            apt-get update -y
            apt-get install -y git
            cd $HOME
            git clone https://github.com/networkslab/slowdns.git >/dev/null 2>&1
            cd slowdns
            chmod +x install.sh
            ./install.sh
            cd $HOME
            rm -rf slowdns
        }
        fun_bar 'fun_inst_slowdns'
        echo -e "\033[1;32mSLOWDNS INSTALADO COM SUCESSO!\033[0m"
        sleep 2
        fun_conexao
    fi
}

# Função para V2Ray
fun_v2rayins() {
    clear
    echo -e "\E[44;1;37m            V2RAY             \E[0m"
    if [[ -e "/etc/v2ray/config.json" ]]; then
        echo -e "\n\033[1;32mV2RAY JÁ ESTÁ INSTALADO!\033[0m"
        echo -e "\n\033[1;33m[1] - Desinstalar V2Ray\n[2] - Alterar Configuração\n[3] - Voltar\033[0m"
        echo -ne "\n\033[1;32mO QUE DESEJA FAZER? \033[0m"
        read option
        case $option in
            1)
                echo -e "\n\033[1;31mDESINSTALANDO V2RAY...\033[0m"
                fun_desinst_v2ray() {
                    apt-get remove --purge v2ray -y >/dev/null 2>&1
                    rm -rf /etc/v2ray
                }
                fun_bar 'fun_desinst_v2ray'
                echo -e "\n\033[1;32mV2RAY DESINSTALADO COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            2)
                echo -e "\n\033[1;32mALTERANDO CONFIGURAÇÃO...\033[0m"
                nano /etc/v2ray/config.json
                systemctl restart v2ray >/dev/null 2>&1
                echo -e "\n\033[1;32mCONFIGURAÇÃO ALTERADA COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            3)
                fun_conexao
                ;;
            *)
                echo -e "\n\033[1;31mOpção inválida!\033[0m"
                sleep 2
                fun_conexao
                ;;
        esac
    else
        echo -e "\n\033[1;32mINSTALANDO V2RAY...\033[0m"
        fun_inst_v2ray() {
            apt-get update -y
            apt-get install -y v2ray
            systemctl enable v2ray >/dev/null 2>&1
            systemctl start v2ray >/dev/null 2>&1
        }
        fun_bar 'fun_inst_v2ray'
        echo -e "\n\033[1;32mV2RAY INSTALADO COM SUCESSO!\033[0m"
        sleep 2
        fun_conexao
    fi
}

# Função para Painel Web
inst_painel() {
    clear
    echo -e "\E[44;1;37m            PAINEL WEB             \E[0m"
    if [[ -e "/var/www/html/index.html" ]]; then
        echo -e "\n\033[1;32mPAINEL WEB JÁ ESTÁ INSTALADO!\033[0m"
        echo -e "\n\033[1;33m[1] - Desinstalar Painel\n[2] - Alterar Configuração\n[3] - Voltar\033[0m"
        echo -ne "\n\033[1;32mO QUE DESEJA FAZER? \033[0m"
        read option
        case $option in
            1)
                echo -e "\n\033[1;31mDESINSTALANDO PAINEL WEB...\033[0m"
                fun_desinst_painel() {
                    apt-get remove --purge apache2 -y >/dev/null 2>&1
                    rm -rf /var/www/html
                }
                fun_bar 'fun_desinst_painel'
                echo -e "\n\033[1;32mPAINEL WEB DESINSTALADO COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            2)
                echo -e "\n\033[1;32mALTERANDO CONFIGURAÇÃO...\033[0m"
                nano /var/www/html/index.html
                systemctl restart apache2 >/dev/null 2>&1
                echo -e "\n\033[1;32mCONFIGURAÇÃO ALTERADA COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            3)
                fun_conexao
                ;;
            *)
                echo -e "\n\033[1;31mOpção inválida!\033[0m"
                sleep 2
                fun_conexao
                ;;
        esac
    else
        echo -e "\n\033[1;32mINSTALANDO PAINEL WEB...\033[0m"
        fun_inst_painel() {
            apt-get update -y
            apt-get install -y apache2
            mkdir -p /var/www/html
            echo "<h1>Painel Web SSHPlus</h1>" > /var/www/html/index.html
            systemctl enable apache2 >/dev/null 2>&1
            systemctl start apache2 >/dev/null 2>&1
        }
        fun_bar 'fun_inst_painel'
        echo -e "\n\033[1;32mPAINEL WEB INSTALADO COM SUCESSO!\033[0m"
        sleep 2
        fun_conexao
    fi
}

# Função para Trojan-GO
fun_trojan() {
    clear
    echo -e "\E[44;1;37m            TROJAN-GO             \E[0m"
    if [[ -e "/bin/trojan-go" ]]; then
        echo -e "\n\033[1;32mTROJAN-GO JÁ ESTÁ INSTALADO!\033[0m"
        echo -e "\n\033[1;33m[1] - Desinstalar Trojan-GO\n[2] - Alterar Configuração\n[3] - Voltar\033[0m"
        echo -ne "\n\033[1;32mO QUE DESEJA FAZER? \033[0m"
        read option
        case $option in
            1)
                echo -e "\n\033[1;31mDESINSTALANDO TROJAN-GO...\033[0m"
                fun_desinst_trojan() {
                    rm -rf /bin/trojan-go
                    rm -rf /etc/trojan-go
                }
                fun_bar 'fun_desinst_trojan'
                echo -e "\n\033[1;32mTROJAN-GO DESINSTALADO COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            2)
                echo -e "\n\033[1;32mALTERANDO CONFIGURAÇÃO...\033[0m"
                nano /etc/trojan-go/config.json
                systemctl restart trojan-go >/dev/null 2>&1
                echo -e "\n\033[1;32mCONFIGURAÇÃO ALTERADA COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            3)
                fun_conexao
                ;;
            *)
                echo -e "\n\033[1;31mOpção inválida!\033[0m"
                sleep 2
                fun_conexao
                ;;
        esac
    else
        echo -e "\n\033[1;32mINSTALANDO TROJAN-GO...\033[0m"
        fun_inst_trojan() {
            apt-get update -y
            wget https://github.com/p4gefau1t/trojan-go/releases/latest/download/trojan-go-linux-amd64.zip -O trojan-go.zip >/dev/null 2>&1
            unzip trojan-go.zip -d /bin/ >/dev/null 2>&1
            chmod +x /bin/trojan-go
            mkdir -p /etc/trojan-go
            cat << EOF > /etc/trojan-go/config.json
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": ["password"]
}
EOF
            systemctl enable trojan-go >/dev/null 2>&1
            systemctl start trojan-go >/dev/null 2>&1
        }
        fun_bar 'fun_inst_trojan'
        echo -e "\n\033[1;32mTROJAN-GO INSTALADO COM SUCESSO!\033[0m"
        sleep 2
        fun_conexao
    fi
}

# Função para XRay (nova)
fun_xray() {
    clear
    echo -e "\E[44;1;37m            GERENCIAR XRAY             \E[0m"
    if netstat -tunlp | grep xray 1>/dev/null 2>&1; then
        echo -e "\n\033[1;33mXRAY JÁ ESTÁ INSTALADO\nDESEJA REINSTALAR? \033[0m"
        echo -ne "\033[1;32mDESEJA CONTINUAR? [s/n]: \033[0m"
        read resp
        [[ "$resp" != @(s|sim|S|SIM) ]] && {
            echo -e "\n\033[1;31mRetornando...\033[0m"
            sleep 2
            fun_conexao
        }
    fi
    echo -e "\n\033[1;32mINSTALANDO XRAY...\033[0m"
    fun_instxray() {
        apt-get update -y
        apt-get install -y unzip
        wget -q https://github.com/XTLS/Xray-core/releases/latest/download/xray-linux-64.zip
        unzip xray-linux-64.zip xray -d /usr/local/bin/
        chmod +x /usr/local/bin/xray
        mkdir -p /etc/xray
        wget -q -O /etc/xray/config.json "https://raw.githubusercontent.com/XTLS/Xray-core/main/config.json"
        systemctl enable xray >/dev/null 2>&1
        systemctl restart xray >/dev/null 2>&1
    }
    fun_bar 'fun_instxray'
    echo -e "\n\033[1;32mXRAY INSTALADO COM SUCESSO!\033[0m"
    sleep 2
    fun_conexao
}

# Função para WebSocket
websocket() {
    clear
    echo -e "\E[44;1;37m            WEBSOCKET             \E[0m"
    if netstat -tuln | grep 'python' | grep '80' >/dev/null; then
        echo -e "\n\033[1;32mWEBSOCKET JÁ ESTÁ ATIVO!\033[0m"
        echo -e "\n\033[1;33m[1] - Desativar WebSocket\n[2] - Alterar Porta\n[3] - Voltar\033[0m"
        echo -ne "\n\033[1;32mO QUE DESEJA FAZER? \033[0m"
        read option
        case $option in
            1)
                echo -e "\n\033[1;31mDESATIVANDO WEBSOCKET...\033[0m"
                pkill -f "python.*80" >/dev/null 2>&1
                echo -e "\n\033[1;32mWEBSOCKET DESATIVADO COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            2)
                echo -e "\n\033[1;32mALTERANDO PORTA...\033[0m"
                echo -ne "\033[1;32mNOVA PORTA: \033[0m"
                read newport
                pkill -f "python.*80" >/dev/null 2>&1
                python -m SimpleHTTPServer $newport >/dev/null 2>&1 &
                echo -e "\n\033[1;32mPORTA ALTERADA COM SUCESSO!\033[0m"
                sleep 2
                fun_conexao
                ;;
            3)
                fun_conexao
                ;;
            *)
                echo -e "\n\033[1;31mOpção inválida!\033[0m"
                sleep 2
                fun_conexao
                ;;
        esac
    else
        echo -e "\n\033[1;32mATIVANDO WEBSOCKET...\033[0m"
        echo -ne "\033[1;32mPORTA: \033[0m"
        read wsport
        python -m SimpleHTTPServer $wsport >/dev/null 2>&1 &
        echo -e "\n\033[1;32mWEBSOCKET ATIVADO COM SUCESSO!\033[0m"
        sleep 2
        fun_conexao
    fi
}

# Função de conexão (menu atualizado)
fun_conexao() {
    clear
    echo -e "\E[44;1;37m         GERENCIAR CONEXÕES         \E[0m"
    echo -e "\033[1;33m[\033[1;31m!\033[1;33m] \033[1;31mATENÇÃO \033[1;33m[\033[1;31m!\033[1;33m]\033[0m"
    echo -e "\033[1;33mPARA QUE TODOS OS PROTOCOLOS\033[0m"
    echo -e "\033[1;33mFUNCIONEM CORRETAMENTE, USEM\033[0m"
    echo -e "\033[1;33mPORTAS MAIORES QUE\033[1;32m 1024\033[0m"
    echo ""
    echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 01 •\033[1;34m]\033[1;37m ➩ \033[1;33mOPENSSH \033[1;32m$(netstat -tuln | grep sshd >/dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")\033[0m"
    echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 02 •\033[1;34m]\033[1;37m ➩ \033[1;33mSQUID PROXY \033[1;32m$(netstat -tuln | grep squid >/dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")\033[0m"
    echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 03 •\033[1;34m]\033[1;37m ➩ \033[1;33mDROPBEAR \033[1;32m$(netstat -tuln | grep dropbear >/dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")\033[0m"
    echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 04 •\033[1;34m]\033[1;37m ➩ \033[1;33mOPENVPN \033[1;32m$(netstat -tuln | grep openvpn >/dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")\033[0m"
    echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 05 •\033[1;34m]\033[1;37m ➩ \033[1;33mSOCKS SSH \033[1;32m$(netstat -tuln | grep 'python' | grep '1080' >/dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")\033[0m"
    echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 06 •\033[1;34m]\033[1;37m ➩ \033[1;33mSOCKS WEBSOCKET \033[1;32m$(netstat -tuln | grep 'python' | grep '80' >/dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")\033[0m"
    echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 07 •\033[1;34m]\033[1;37m ➩ \033[1;33mSOCKS OPENVPN \033[1;32m$(netstat -tuln | grep 'python' | grep '2080' >/dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")\033[0m"
    echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 08 •\033[1;34m]\033[1;37m ➩ \033[1;33mSSL TUNNEL \033[1;32m$(netstat -tuln | grep stunnel4 >/dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")\033[0m"
    echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 09 •\033[1;34m]\033[1;37m ➩ \033[1;33mSSLH \033[1;32m$(netstat -tuln | grep sslh >/dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")\033[0m"
    echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 10 •\033[1;34m]\033[1;37m ➩ \033[1;33mCHISEL \033[1;32m$(docker ps | grep chisel >/dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")\033[0m"
    echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 11 •\033[1;34m]\033[1;37m ➩ \033[1;33mSLOWDNS \033[1;32m$(ps x | grep slowdns | grep -v grep >/dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")\033[0m"
    echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 12 •\033[1;34m]\033[1;37m ➩ \033[1;33mV2RAY \033[1;32m$(ps x | grep v2ray | grep -v grep >/dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")\033[0m"
    echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 13 •\033[1;34m]\033[1;37m ➩ \033[1;33mPAINEL WEB \033[0m"
    echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 14 •\033[1;34m]\033[1;37m ➩ \033[1;33mLIMPAR DADOS V2RAY \033[0m"
    if [[ -e "/bin/trojan-go" ]]; then
        echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 15 •\033[1;34m]\033[1;37m ➩ \033[1;33mTROJAN-GO \033[1;32m$(ps x | grep trojan-go | grep -v grep >/dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")\033[0m"
    else
        echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 15 •\033[1;34m]\033[1;37m ➩ \033[1;33mTROJAN-GO \033[1;31m○ \033[0m"
    fi
    if [[ -e "/usr/local/bin/xray" ]]; then
        echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 16 •\033[1;34m]\033[1;37m ➩ \033[1;33mXRAY \033[1;32m$(ps x | grep xray | grep -v grep >/dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")\033[0m"
    else
        echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 16 •\033[1;34m]\033[1;37m ➩ \033[1;33mXRAY \033[1;31m○ \033[0m"
    fi
    echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 17 •\033[1;34m]\033[1;37m ➩ \033[1;33mWEBSOCKET \033[0m"
    echo -e "\033[01;31m║\033[1;31m\033[1;34m[\033[1;37m 00 •\033[1;34m]\033[1;37m ➩ \033[1;33mVOLTAR \033[0m"
    echo -e "\033[0;31m╚═══════════════════════════════════════╝\033[0m"
    echo -ne "\n\033[1;32mO QUE DESEJA FAZER \033[1;33m?\033[1;31m\033[1;37m "
    read x
    case $x in
        1|01)
            fun_openssh
            ;;
        2|02)
            fun_squid
            ;;
        3|03)
            fun_drop
            ;;
        4|04)
            fun_openvpn
            ;;
        5|05)
            fun_socks
            ;;
        6|06)
            socks_ws
            ;;
        7|07)
            socks_openvpn
            ;;
        8|08)
            inst_ssl
            ;;
        9|09)
            inst_sslh
            ;;
        10)
            fun_chisel
            ;;
        11)
            slow_setup
            ;;
        12)
            fun_v2rayins
            ;;
        13)
            inst_painel
            ;;
        14)
            clear
            echo -e "\033[1;32mLIMPANDO DADOS V2RAY...\033[0m"
            rm -rf /etc/v2ray/* >/dev/null 2>&1
            echo -e "\n\033[1;32mDADOS V2RAY LIMPOS COM SUCESSO!\033[0m"
            sleep 2
            fun_conexao
            ;;
        15)
            fun_trojan
            ;;
        16)
            fun_xray
            ;;
        17)
            websocket
            ;;
        0|00)
            clear
            menu
            ;;
        *)
            echo -e "\n\033[1;31mOpção inválida!\033[0m"
            sleep 2
            fun_conexao
            ;;
    esac
}

# Função de menu principal
menu() {
    clear
    echo -e "\E[44;1;37m         SSHPLUS MANAGER         \E[0m"
    echo -e "\n\033[1;32m[1] - Gerenciar Conexões\n[2] - Outras Opções\n[0] - Sair\033[0m"
    echo -ne "\n\033[1;32mO QUE DESEJA FAZER? \033[0m"
    read option
    case $option in
        1)
            fun_conexao
            ;;
        2)
            echo -e "\n\033[1;31mFunção não implementada!\033[0m"
            sleep 2
            menu
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "\n\033[1;31mOpção inválida!\033[0m"
            sleep 2
            menu
            ;;
    esac
}

# Iniciar o script
menu