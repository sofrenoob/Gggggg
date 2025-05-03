#!/bin/bash

# DNS Avançado AlfaMenager
# by @alfalemos 👾🥷

echo -e "\e[1;32m[+] Instalando DNS avançado dnsmasq...\e[0m"
apt install -y dnsmasq

# Backup config original
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.bkp

# Config custom
cat > /etc/dnsmasq.conf << EOF
port=53
domain-needed
bogus-priv
server=8.8.8.8
server=8.8.4.4
server=1.1.1.1
listen-address=127.0.0.1
cache-size=10000
EOF

# Reinicia serviço
systemctl restart dnsmasq

echo -e "\e[1;32m[+] DNS AlfaMenager ativo e otimizado!\e[0m"
