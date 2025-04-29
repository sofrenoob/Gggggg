#!/bin/bash

# Verifica se é root
if [[ $EUID -ne 0 ]]; then
   echo "Este script precisa ser executado como root!" 
   exit 1
fi

echo "Atualizando sistema..."
apt update && apt upgrade -y

echo "Instalando o Dante SOCKS5..."
apt install dante-server -y

# Detecta a interface de rede automaticamente
INTERFACE=$(ip route | grep default | awk '{print $5}')

# Detecta o IP da VPS
IPVPS=$(ip -4 addr show $INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

echo "Criando arquivo de configuração em /etc/danted.conf"

cat > /etc/danted.conf << EOF
logoutput: /var/log/danted.log

internal: 0.0.0.0 port = 80
external: $IPVPS

method: none
user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
    log: connect disconnect error
}
EOF

echo "Habilitando e iniciando serviço do Dante..."
systemctl enable danted
systemctl restart danted

# Libera a porta no firewall (se UFW estiver instalado)
if command -v ufw &> /dev/null
then
    echo "Liberando porta 80 no firewall..."
    ufw allow 80/tcp
    ufw reload
fi

echo "Pronto! SOCKS5 rodando na porta 80."
echo "Para testar: curl --proxy socks5h://$IPVPS:80 http://www.google.com"
