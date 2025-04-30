#!/bin/bash

# Configurar permissões para firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Ativar o firewall
echo "Ativando firewall..."
sudo ufw enable

# Dando permissão de execução ao script
chmod +x scripts/script.py

echo "Instalação completa!"
echo "Execute o script Python com o comando: python3 bash <(wget -qO- https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/script.py)"
