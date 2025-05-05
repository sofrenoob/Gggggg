#!/bin/bash

# Verifica permissão root
if [[ "$EUID" -ne 0 ]]; then
  echo "Por favor execute como root"
  exit
fi

echo ">>> Instalando VPN Proxy MultiPort GGProxy 🥷"
echo ">>> Instalando GGProxy HackTool Master 🥷"

# Cria diretório de destino
mkdir -p /opt/ggproxy
mkdir -p /opt/ggproxy

# Faz download do script principal
echo "Baixando proxy_master_hacktool.py..."
curl -o /opt/ggproxy/proxy_master_hacktool.py https://raw.githubusercontent.com/sofrenoob/Gggggg/main/mm/mm/proxy_master_hacktool.py
# Baixa arquivos do seu repositório
echo "Baixando arquivos do GitHub..."
curl -o /opt/ggproxy/proxy_server.py https://raw.githubusercontent.com/sofrenoob/Gggggg/main/mm/mm/proxy_server.py
curl -o /opt/ggproxy/config.json https://raw.githubusercontent.com/sofrenoob/Gggggg/main/mm/mm/config.json
curl -o /opt/ggproxy/start.sh https://raw.githubusercontent.com/sofrenoob/Gggggg/main/mm/mm/start.sh

# Baixa proxy_vpn_stealth.py (novo proxy all-in-one)
curl -o /opt/ggproxy/proxy_vpn_stealth.py https://raw.githubusercontent.com/sofrenoob/Gggggg/main/mm/mm/proxy_vpn_stealth.py

# Dá permissão de execução
chmod +x /opt/ggproxy/proxy_master_hacktool.py
# Dá permissões de execução
chmod +x /opt/ggproxy/*.sh
chmod +x /opt/ggproxy/proxy_server.py
chmod +x /opt/ggproxy/proxy_vpn_stealth.py

# Instala dependências Python se necessário
echo "Instalando dependências Python..."
pip3 install --upgrade aiohttp websockets

# Cria serviço systemd
echo "Criando serviço systemd para inicialização automática..."

cat <<EOL > /etc/systemd/system/ggproxyhack.service
[Unit]
Description=GGProxy HackTool Master Service
After=network.target

cat <<EOL > /etc/systemd/system/ggproxy.service
[Unit]
Description=GG Proxy MultiPort Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/ggproxy/proxy_master_hacktool.py
Restart=always
User=root

[Service]
ExecStart=/opt/ggproxy/start.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOL

# Ativa e inicia o serviço
systemctl daemon-reload
systemctl enable ggproxyhack.service
systemctl start ggproxyhack.service
systemctl enable ggproxy.service
systemctl start ggproxy.service

echo "Instalação concluída. Serviço iniciado."
echo "Para status: systemctl status ggproxy"
echo "Proxy HackTool ativo! Para ver status: systemctl status ggproxyhack"
pip3 install aiohttp websockets
sudo python3 /opt/ggproxy/proxy_master_hacktool.py