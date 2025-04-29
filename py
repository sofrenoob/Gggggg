#!/bin/bash

# Verifica se é root
if [[ $EUID -ne 0 ]]; then
   echo "Este script precisa ser executado como root!" 
   exit 1
fi

# Atualiza o sistema e instala o Dante
echo "Atualizando o sistema e instalando o Dante SOCKS5..."
apt update && apt upgrade -y
apt install dante-server -y

# Cria o arquivo de configuração do Dante SOCKS5
echo "Configurando o Dante SOCKS5 na porta 80..."
cat > /etc/danted.conf << EOF
logoutput: /var/log/danted.log

internal: 0.0.0.0 port = 80
external: $(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

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

# Habilita o serviço no boot
echo "Ativando o serviço Dante no boot..."
systemctl enable danted

# Reinicia o Dante para aplicar a nova configuração
echo "Reiniciando o Dante SOCKS5..."
systemctl restart danted

# Libera a porta 80 no UFW (caso o firewall esteja ativado)
if command -v ufw &> /dev/null
then
    echo "Liberando porta 80 no firewall (UFW)..."
    ufw allow 80/tcp
fi

# Exibe informações de finalização
echo "Instalação concluída!"
echo "SOCKS5 agora rodando na porta 80."
echo "Para testar: curl --proxy socks5h://IP_DA_VPS:80 http://www.google.com"
