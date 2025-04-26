export DEBIAN_FRONTEND=noninteractive
portas=("80" "8080" "443" "444" "445" "7000" "7100" "7200" "7300" "7400" "7500")
porta_aberta=false
for porta in "${portas[@]}"; do
ss -tunlp | grep -w "$porta" > /dev/null
if [ "$?" -eq 0 ]; then
porta_aberta=true
else
porta_aberta=false
fi
done
instalar_modo_normal() {
if [ "$porta_aberta" = true ]; then
echo "Uma ou mais portas estão em uso. A instalação será interrompida."
exit 1
fi
systemctl disable --now syslog.socket rsyslog.service   > /dev/null  2>&1
service rsyslog stop  > /dev/null  2>&1
systemctl disable --now systemd-journald.service systemd-journald-audit.socket systemd-journald-dev-log.socket systemd-journald.socket > /dev/null  2>&1
apt-get update > /dev/null
apt-get install -y wget unzip  > /dev/null
opcao=0
echo "Selecione o modo de instalação:"
echo "1. AMD64"
echo "2. I386"
echo "3. ARM"
echo "4. ARM64"
while true; do
read -p "Digite o número da opção desejada: " opcao
case $opcao in
1)
echo "Instalando o proxy e udp amd64..."
break
;;
2)
echo "Instalando o proxy e udp i386..."
break
;;
3)
echo "Instalando o proxy eudp arm..."
break
;;
4)
echo "Instalando o proxy e udp arm64..."
break
;;
*)
echo "Opção inválida. Digite um número válido."
;;
esac
done
if [ "$opcao" -eq 1 ]; then
wget -O proxy.zip https://download.anyvpn.top/wsproxy/download.php?arch=amd64 > /dev/null 2>&1
:
elif [ "$opcao" -eq 2 ]; then
wget -O proxy.zip https://download.anyvpn.top/wsproxy/download.php?arch=386 > /dev/null  2>&1
:
elif [ "$opcao" -eq 3 ]; then
wget -O proxy.zip https://download.anyvpn.top/wsproxy/download.php?arch=arm > /dev/null 2>&1
:
elif [ "$opcao" -eq 4 ]; then
wget -O proxy.zip https://download.anyvpn.top/wsproxy/download.php?arch=arm64 > /dev/null  2>&1
:
fi
unzip proxy.zip > /dev/null
cd /root/proxy
if [ -f "inicia.sh" ]; then
rm inicia.sh > /dev/null
fi
cp ssh.sh inicia.sh > /dev/null
chmod 777 wsproxy dns.sh ssl openproxy inicia.sh > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7000/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7100/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7200/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7300/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7400/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7500/udpgw > /dev/null
echo "Proxy instalado e configurado com sucesso!"
echo""
echo "EXECUTA A OPÇÃO 5 E INFORME O IP E O TOKEN AO REVENDEDOR"
echo""
echo "APOS LIBERADO OPÇÃO  6 PARA INICIAR"
}
instalar_sslh() {
if [ "$porta_aberta" = true ]; then
echo "Uma ou mais portas estão em uso. A instalação será interrompida."
exit 1
fi
echo "Instalando o proxy no modo SSLH..."
systemctl disable --now syslog.socket rsyslog.service  > /dev/null  2>&1
service rsyslog stop   > /dev/null  2>&1
systemctl disable --now systemd-journald.service systemd-journald-audit.socket systemd-journald-dev-log.socket systemd-journald.socket > /dev/null  2>&1
apt-get update > /dev/null
apt-get install -y wget unzip  > /dev/null
opcao=0
echo "Selecione o modo de instalação:"
echo "1. AMD64"
echo "2. I386"
echo "3. ARM"
echo "4. ARM64"
while true; do
read -p "Digite o número da opção desejada: " opcao
case $opcao in
1)
echo "Instalando o proxy e udp amd64..."
break
;;
2)
echo "Instalando o proxy e udp i386..."
break
;;
3)
echo "Instalando o proxy e udp arm..."
break
;;
4)
echo "Instalando o proxy e udp  arm64..."
break
;;
*)
echo "Opção inválida. Digite um número válido."
;;
esac
done
if [ "$opcao" -eq 1 ]; then
wget -O proxy.zip https://download.anyvpn.top/wsproxy/download.php?arch=amd64 > /dev/null 2>&1
:
elif [ "$opcao" -eq 2 ]; then
wget -O proxy.zip https://download.anyvpn.top/wsproxy/download.php?arch=386 > /dev/null  2>&1
:
elif [ "$opcao" -eq 3 ]; then
wget -O proxy.zip https://download.anyvpn.top/wsproxy/download.php?arch=arm > /dev/null 2>&1
:
elif [ "$opcao" -eq 4 ]; then
wget -O proxy.zip https://download.anyvpn.top/wsproxy/download.php?arch=arm64 > /dev/null  2>&1
:
fi
unzip proxy.zip > /dev/null
cd /root/proxy
if [ -f "inicia.sh" ]; then
rm inicia.sh > /dev/null
fi
cp sslh.sh inicia.sh > /dev/null
chmod 777 wsproxy ssl dns.sh openproxy inicia.sh > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7000/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7100/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7200/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7300/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7400/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7500/udpgw > /dev/null
apt-get install -y sslh > /dev/null
cd /root
wget https://download.anyvpn.top/wsproxy/sslh > /dev/null  2>&1
mv sslh /etc/default/sslh > /dev/null
/etc/init.d/sslh restart > /dev/null
if command -v openvpn &> /dev/null; then
if grep -q "port-share 127.0.0.1 2222" /etc/openvpn/server.conf; then
echo "A porta 2222 já está configurada no arquivo server.conf."
else
echo "port-share 127.0.0.1 2222" | sudo tee -a /etc/openvpn/server.conf
/etc/init.d/openvpn restart > /dev/null
fi
fi
echo "Proxy e SSLH instalado e configurado com sucesso!"
echo""
echo "EXECUTA A OPÇÃO 5 E INFORME O IP E O TOKEN AO REVENDEDOR"
echo""
echo "APOS LIBERADO OPÇÃO  6 PARA INICIAR"
}
instalar_openvpn() {
if [ "$porta_aberta" = true ]; then
echo "Uma ou mais portas estão em uso. A instalação será interrompida."
exit 1
fi
echo "Instalando o proxy no modo OPENVPN.."
if ! command -v openvpn &> /dev/null; then
echo "OpenVPN não está instalado. Por favor, instale o OpenVPN antes de continuar."
exit 1
fi
if grep -q "port-share 127.0.0.1 2222" /etc/openvpn/server.conf; then
echo "A porta 2222 já está configurada no arquivo server.conf."
else
echo "port-share 127.0.0.1 2222" | sudo tee -a /etc/openvpn/server.conf
/etc/init.d/openvpn restart > /dev/null
fi
systemctl disable --now syslog.socket rsyslog.service > /dev/null 2>&1
systemctl disable --now systemd-journald.service systemd-journald-audit.socket systemd-journald-dev-log.socket systemd-journald.socket > /dev/null  2>&1
/etc/init.d/rsyslog stop > /dev/null 2>&1
apt-get update > /dev/null
apt-get install -y wget unzip  > /dev/null
opcao=0
echo "Selecione o modo de instalação:"
echo "1. AMD64"
echo "2. I386"
echo "3. ARM"
echo "4. ARM64"
while true; do
read -p "Digite o número da opção desejada: " opcao
case $opcao in
1)
echo "Instalando o proxy e udp amd64..."
break
;;
2)
echo "Instalando o proxy e udp i386..."
break
;;
3)
echo "Instalando o proxy e udp arm..."
break
;;
4)
echo "Instalando o proxy e udp  arm64..."
break
;;
*)
echo "Opção inválida. Digite um número válido."
;;
esac
done
if [ "$opcao" -eq 1 ]; then
wget -O proxy.zip https://download.anyvpn.top/wsproxy/download.php?arch=amd64 > /dev/null 2>&1
:
elif [ "$opcao" -eq 2 ]; then
wget -O proxy.zip https://download.anyvpn.top/wsproxy/download.php?arch=386 > /dev/null  2>&1
:
elif [ "$opcao" -eq 3 ]; then
wget -O proxy.zip https://download.anyvpn.top/wsproxy/download.php?arch=arm > /dev/null 2>&1
:
elif [ "$opcao" -eq 4 ]; then
wget -O proxy.zip https://download.anyvpn.top/wsproxy/download.php?arch=arm64 > /dev/null  2>&1
:
fi
unzip proxy.zip > /dev/null
cd /root/proxy
if [ -f "inicia.sh" ]; then
rm inicia.sh > /dev/null
fi
cp openvpn.sh inicia.sh > /dev/null
chmod 777 wsproxy ssl dns.sh openproxy inicia.sh > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7000/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7100/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7200/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7300/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7400/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7500/udpgw > /dev/null
echo "Proxy OPENVPN instalado e configurado com sucesso!"
echo""
echo "EXECUTA A OPÇÃO 5 E INFORME O IP E O TOKEN AO REVENDEDOR"
echo""
echo "APOS LIBERADO OPÇÃO  6 PARA INICIAR"
}
instalar_badvpn() {
if [ "$porta_aberta" = true ]; then
echo "Uma ou mais portas estão em uso. A instalação será interrompida."
exit 1
fi
echo "Instalando BADVPN 7000 A 7500.."
systemctl disable --now syslog.socket rsyslog.service > /dev/null 2>&1
systemctl disable --now systemd-journald.service systemd-journald-audit.socket systemd-journald-dev-log.socket systemd-journald.socket > /dev/null  2>&1
/etc/init.d/rsyslog stop > /dev/null 2>&1
apt-get update > /dev/null
apt-get install -y wget unzip  > /dev/null
opcao=0
echo "Selecione o modo de instalação:"
echo "1. AMD64"
echo "2. I386"
echo "3. ARM"
echo "4. ARM64"
while true; do
read -p "Digite o número da opção desejada: " opcao
case $opcao in
1)
echo "udp amd64..."
break
;;
2)
echo "udp i386..."
break
;;
3)
echo "udp arm..."
break
;;
4)
echo "udp  arm64..."
break
;;
*)
echo "Opção inválida. Digite um número válido."
;;
esac
done
if [ "$opcao" -eq 1 ]; then
wget -O proxy.zip https://download.anyvpn.top/wsproxy/download.php?arch=amd64 > /dev/null 2>&1
:
elif [ "$opcao" -eq 2 ]; then
wget -O proxy.zip https://download.anyvpn.top/wsproxy/download.php?arch=386 > /dev/null  2>&1
:
elif [ "$opcao" -eq 3 ]; then
wget -O proxy.zip https://download.anyvpn.top/wsproxy/download.php?arch=arm > /dev/null 2>&1
:
elif [ "$opcao" -eq 4 ]; then
wget -O proxy.zip https://download.anyvpn.top/wsproxy/download.php?arch=arm64 > /dev/null  2>&1
:
fi
unzip proxy.zip > /dev/null 2>&1
cd /root/proxy
if [ -f "inicia.sh" ]; then
rm inicia.sh > /dev/null
fi
cp udp.sh inicia.sh > /dev/null
chmod 777 wsproxy ssl dns.sh  openproxy inicia.sh > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7000/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7100/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7200/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7300/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7400/udpgw > /dev/null
chmod 777 /root/proxy/udpgw/cmd/7500/udpgw > /dev/null
echo "UDP instalado e configurado com sucesso!"
echo""
echo "EXECUTA A OPÇÃO 5 E INFORME O IP E O TOKEN AO REVENDEDOR"
echo""
echo "APOS LIBERADO OPÇÃO  6 PARA INICIAR"
}
ver_iptoken(){
echo "Credenciais para liberar ..."
echo " "
/root/proxy/wsproxy
}
create_service() {
/root/proxy/inicia.sh > /dev/null
echo "O serviço iniciado com sucesso."
}
remove_service() {
screen -S openvpn -X quit > /dev/null
screen -S ws -X quit > /dev/null
screen -S ssl -X quit > /dev/null
screen -S udp7000 -X quit > /dev/null
screen -S udp7100 -X quit > /dev/null
screen -S udp7200 -X quit > /dev/null
screen -S udp7300 -X quit > /dev/null
screen -S udp7400 -X quit > /dev/null
screen -S udp7500 -X quit > /dev/null
echo "O serviço foi parado com sucesso."
}
restart_service() {
screen -S openvpn -X quit > /dev/null
screen -S ws -X quit > /dev/null
screen -S ssl -X quit > /dev/null
screen -S udp7000 -X quit > /dev/null
screen -S udp7100 -X quit > /dev/null
screen -S udp7200 -X quit > /dev/null
screen -S udp7300 -X quit > /dev/null
screen -S udp7400 -X quit > /dev/null
screen -S udp7500 -X quit > /dev/null
/root/proxy/inicia.sh > /dev/null
echo "O serviço reiniciado com sucesso."
}
automatico(){
script_path="/root/proxy/inicia.sh > /dev/null"
echo "Escolha uma opção:"
echo "1. Adicionar início automático."
echo "2. Remover início automático."
read -p "Opção: " option
if [[ "$option" != "1" && "$option" != "2" ]]; then
echo "Opção inválida. Saindo."
exit 1
fi
if crontab -l | grep -q "$script_path"; then
if [ "$option" == "1" ]; then
echo "O script já está agendado."
else
crontab -l | grep -v "$script_path" | crontab -
echo "Remoção do início automático."
fi
else
if [ "$option" == "2" ]; then
echo "O script não está agendado."
else
(crontab -l ; echo "@reboot sleep 60 && $script_path") | crontab -
echo "Início automático sucesso."
fi
fi
}
dns(){
script_path="/root/proxy/dns.sh"
echo "Escolha uma opção:"
echo "1. Adicionar início automático."
echo "2. Remover início automático."
read -p "Opção: " option
if [ "$option" == "1" ]; then
if crontab -l | grep -q "$script_path"; then
echo "O script já está agendado."
else
(crontab -l ; echo "@reboot $script_path > /dev/null") | crontab -
echo "Início automático  com sucesso."
fi
elif [ "$option" == "2" ]; then
if crontab -l | grep -q "$script_path"; then
crontab -l | grep -v "$script_path" | crontab -
echo "Remoção do início automático"
else
echo "O script não está agendado."
fi
else
echo "Opção inválida. Saindo."
exit 1
fi
}
alterar_cfg() {
echo "SELECIONE O MODO DE INSTALAÇÃO:"
echo "1. MODO NORMAL + BADVPN 7000 A 7500"
echo "2. MODO SSLH + BADVPN 7000 A 7500"
echo "3. MODO OPENVPN"
echo "4. BADVPN 7000 A 7500"
read -p "Opção: " option
case $option in
1)
screen -S openvpn -X quit > /dev/null
screen -S ws -X quit > /dev/null
screen -S ssl -X quit > /dev/null
screen -S udp7000 -X quit > /dev/null
screen -S udp7100 -X quit > /dev/null
screen -S udp7200 -X quit > /dev/null
screen -S udp7300 -X quit > /dev/null
screen -S udp7400 -X quit > /dev/null
screen -S udp7500 -X quit > /dev/null
cd /root/proxy
if [ -f "inicia.sh" ]; then
rm inicia.sh > /dev/null
fi
cp ssh.sh inicia.sh > /dev/null
chmod 777  /root/proxy/inicia.sh > /dev/null
/root/proxy/inicia.sh > /dev/null
echo "Modo normal + BADVPN 7000 a 7500 configurado com sucesso."
;;
2)
screen -S openvpn -X quit > /dev/null
screen -S ws -X quit > /dev/null
screen -S ssl -X quit > /dev/null
screen -S udp7000 -X quit > /dev/null
screen -S udp7100 -X quit > /dev/null
screen -S udp7200 -X quit > /dev/null
screen -S udp7300 -X quit > /dev/null
screen -S udp7400 -X quit > /dev/null
screen -S udp7500 -X quit > /dev/null
rm /root/sslh  > /dev/null  2>&1
cd /root
apt-get install -y sslh > /dev/null
wget https://download.anyvpn.top/wsproxy/sslh > /dev/null  > /dev/null  2>&1
mv sslh /etc/default/sslh > /dev/null
/etc/init.d/sslh restart > /dev/null
cd /root/proxy
if [ -f "inicia.sh" ]; then
rm inicia.sh > /dev/null
fi
cp sslh.sh inicia.sh > /dev/null
chmod 777  /root/proxy/inicia.sh > /dev/null
/root/proxy/inicia.sh > /dev/null
echo "Modo SSLH + BADVPN 7000 a 7500 configurado com sucesso."
;;
3)
screen -S openvpn -X quit > /dev/null
screen -S ws -X quit > /dev/null
screen -S ssl -X quit > /dev/null
screen -S udp7000 -X quit > /dev/null
screen -S udp7100 -X quit > /dev/null
screen -S udp7200 -X quit > /dev/null
screen -S udp7300 -X quit > /dev/null
screen -S udp7400 -X quit > /dev/null
screen -S udp7500 -X quit > /dev/null
if [ -f "inicia.sh" ]; then
rm inicia.sh > /dev/null
fi
cd /root/proxy
cp openvpn.sh inicia.sh > /dev/null
chmod 777  /root/proxy/inicia.sh > /dev/null
/root/proxy/inicia.sh > /dev/null
echo "Modo OPENVPN configurado com sucesso."
;;
4)
screen -S openvpn -X quit > /dev/null
screen -S ws -X quit > /dev/null
screen -S ssl -X quit > /dev/null
screen -S udp7000 -X quit > /dev/null
screen -S udp7100 -X quit > /dev/null
screen -S udp7200 -X quit > /dev/null
screen -S udp7300 -X quit > /dev/null
screen -S udp7400 -X quit > /dev/null
screen -S udp7500 -X quit > /dev/null
if [ -f "inicia.sh" ]; then
rm inicia.sh > /dev/null
fi
cp udp.sh inicia.sh > /dev/null
chmod 777  /root/proxy/inicia.sh > /dev/null
/root/proxy/inicia.sh > /dev/null
echo "BADVPN 7000 a 7500 configurado com sucesso."
;;
*)
echo "Opção inválida. Saindo."
exit 1
;;
esac
}
remover(){
script_path="/root/proxy/dns.sh"
script_path2="/root/proxy/inicia.sh"
if crontab -l | grep -q "$script_path"; then
crontab -l | grep -v "$script_path" | crontab -
fi
if crontab -l | grep -q "$script_path2"; then
crontab -l | grep -v "$script_path2" | crontab -
fi
screen -S openvpn -X quit > /dev/null
screen -S ws -X quit > /dev/null
screen -S ssl -X quit > /dev/null
screen -S udp7000 -X quit > /dev/null
screen -S udp7100 -X quit > /dev/null
screen -S udp7200 -X quit > /dev/null
screen -S udp7300 -X quit > /dev/null
screen -S udp7400 -X quit > /dev/null
screen -S udp7500 -X quit > /dev/null
apt-get remove sslh --purge > /dev/null
rm -rf /root/proxy /root/proxy.* script.sh script.sh.*
> /dev/null
exit 1
}
fixopen(){
config_lines=(
"net.ipv4.ip_forward=1"
"net.ipv6.conf.all.disable_ipv6=1"
"net.ipv6.conf.default.disable_ipv6=1"
"net.ipv6.conf.lo.disable_ipv6=1"
)
already_exists=0
for line in "${config_lines[@]}"; do
if grep -q "^$line" /etc/sysctl.conf; then
already_exists=1
break
fi
done
if [ "$already_exists" -eq 0 ]; then
for line in "${config_lines[@]}"; do
echo "$line" >> /etc/sysctl.conf
done
sysctl -p
fi
gateway=$(ip route | grep default | awk '{print $3}')
interface=$(ip route | grep default | awk '{print $5}')
if [ -z "$gateway" ] || [ -z "$interface" ]; then
echo "Não foi possível detectar a placa de rede conectada à internet."
exit 1
fi
echo "Placa de rede com saída para a Internet:"
echo "Gateway Padrão: $gateway"
echo "Interface de Rede: $interface"
iptables -t nat -A POSTROUTING -o $interface -j MASQUERADE
script_path="@reboot /sbin/iptables -t nat -A POSTROUTING -o $interface -j MASQUERADE"
echo "NAT configurada com sucesso para a placa de rede $interface."
if crontab -l | grep -q "$script_path"; then
echo "O script já está agendado."
else
(crontab -l ; echo "$script_path > /dev/null") | crontab -
echo "Início automático  com sucesso."
fi
}
checkuser() {
echo "CHECKUSER:"
echo "1. ATIVAR CHECKUSER"
echo "2. PARAR"
echo "3. REINICIAR"
echo "4. INICIO AUTOMÁTICO"
read -p "Opção: " option
case $option in
1)
cd /root/proxy
chmod 777  /root/proxy/checkuser.sh > /dev/null
chmod 777  /root/proxy/checkuser > /dev/null
/root/proxy/checkuser.sh > /dev/null
echo "CHECKUSER INICIADO NA PORTA 5000."
;;
2)
cd /root/proxy
screen -S checkuser -X quit > /dev/null
echo "CHECKUSER PARADO."
;;
3)
cd /root/proxy
screen -S checkuser -X quit > /dev/null
/root/proxy/checkuser.sh > /dev/null
echo "CHECKUSER REINICIADO."
;;
4)
script_path="/root/proxy/checkuser.sh"
echo "Escolha uma opção:"
echo "1. Adicionar início automático."
echo "2. Remover início automático."
read -p "Opção: " option
if [ "$option" == "1" ]; then
if crontab -l | grep -q "$script_path"; then
echo "O script já está agendado."
else
(crontab -l ; echo "@reboot $script_path > /dev/null") | crontab -
echo "Início automático  com sucesso."
fi
elif [ "$option" == "2" ]; then
if crontab -l | grep -q "$script_path"; then
crontab -l | grep -v "$script_path" | crontab -
echo "Remoção do início automático"
else
echo "O script não está agendado."
fi
else
echo "Opção inválida. Saindo."
exit 1
fi
;;
esac
}
echo "SELECIONE O MODO DE INSTALAÇÃO:"
echo "1. MODO NORMAL + BADVPN 7000 A 7500"
echo "2. MODO SSLH + BADVPN 7000 A7500"
echo "3. MODO OPENVPN"
echo "4. BADVPN 7000 A7500"
echo "5. VER IP E TOKEN"
echo "6. INICIAR"
echo "7. REINICIAR"
echo "8. PARAR"
echo "9. INICIO AUTOMÁTICO"
echo "10. CONFIGURAR DNS AUTOMÁTICO"
echo "11. MUDAR OS CONFIGURAÇÕES"
echo "12. REMOVER TUDO"
echo "13. CORRIGIR OPEN NÃO GERAR DADOS"
echo "14. CHECKUSER"
read -p "Digite o número da opção desejada: " opcao
case $opcao in
1)
instalar_modo_normal
;;
2)
instalar_sslh
;;
3)
instalar_openvpn
;;
4)
instalar_badvpn
;;
5)
ver_iptoken
;;
6)
create_service
;;
7)
restart_service
;;
8)
remove_service
;;
9)
automatico
;;
10)
dns
;;
11)
alterar_cfg
;;
12)
remover
;;
13)
fixopen
;;
14)
checkuser
;;
*)
echo "Opção inválida."
exit 1
;;
esac
