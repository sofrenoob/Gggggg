#!/bin/bash

echo "Configurando Stunnel..."

# Criar diretório
sudo mkdir -p /etc/stunnel

# Gerar stunnel.conf
sudo tee /etc/stunnel/stunnel.conf > /dev/null <<EOF
pid = /var/run/stunnel.pid
output = /var/log/stunnel.log
foreground = no

[proxy-tls]
accept = 443
connect = 127.0.0.1:8080
cert = /etc/stunnel/stunnel.pem
key = /etc/stunnel/stunnel.pem
EOF

# Gerar certificado
sudo openssl req -new -x509 -days 3650 -nodes \
  -out /etc/stunnel/stunnel.pem \
  -keyout /etc/stunnel/stunnel.pem \
  -subj "/C=BR/ST=SP/L=City/O=Company/CN=alfa-cloud"

# Ativar e iniciar o serviço stunnel
sudo systemctl enable stunnel4
sudo systemctl restart stunnel4

echo "Stunnel configurado e em execução na porta 443."
