#!/bin/bash
echo "=== Instalando Alfa Cloud ==="

# Atualizar pacotes
sudo apt update

# Instalar dependências
sudo apt install -y nodejs npm sqlite3 libsqlite3-dev badvpn stunnel4 ufw git

# Clonar o projeto do GitHub
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

# Iniciar serviços auxiliares (BadVPN, Stunnel, Proxy Checker)
bash scripts/start_services.sh

# Iniciar backend com PM2
pm2 start backend/server.js --name alfa-cloud

echo "=== Instalação concluída com sucesso! Alfa Cloud está rodando. ==="
