#!/bin/bash
echo "=== Instalando Alfa Cloud ==="

# Atualizar pacotes
sudo apt update

# Instalar dependências principais
sudo apt install -y curl wget git ufw sqlite3 libsqlite3-dev build-essential stunnel

# Instalar Node.js (via NodeSource) e PM2
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g pm2

# Clonar o projeto
if [ -d "Gggggg" ]; then
  echo "Diretório Gggggg já existe, removendo..."
  rm -rf Gggggg
fi
git clone https://github.com/sofrenoob/Gggggg.git
cd Gggggg/Men/alfa-cloud

# Instalar dependências do backend
cd backend
npm install
cd ..

# Inicializar banco de dados
node scripts/initialize_db.js

# Configurar Stunnel
bash scripts/setup_stunnel.sh

# Liberar portas com UFW
bash scripts/manage_ports.sh

# Baixar e iniciar BadVPN (porta 7300)
mkdir -p ~/badvpn
cd ~/badvpn
wget -O badvpn-udpgw https://github.com/ambrop72/badvpn/releases/download/1.999.130/badvpn-1.999.130-linux-x86_64
chmod +x badvpn-udpgw
nohup ./badvpn-udpgw --listen-addr 127.0.0.1:7300 > /dev/null 2>&1 &

# Iniciar Stunnel
bash scripts/start_stunnel.sh

# Iniciar backend com PM2
pm2 start backend/server.js --name alfa-cloud

echo "=== Instalação concluída com sucesso! Alfa Cloud está rodando. ==="
