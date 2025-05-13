#!/bin/bash

echo "=== INSTALANDO ALFA CLOUD VPN SERVER ==="

# Atualizando pacotes
apt update && apt upgrade -y

# Instalando dependências do sistema
apt install -y curl unzip docker.io docker-compose git

# Habilitando e iniciando o Docker
systemctl enable docker
systemctl start docker

# Baixando projeto do GitHub
echo "Baixando projeto alfa-cloud..."
curl -L -o alfa-cloud.zip https://github.com/sofrenoob/Gggggg/raw/main/4/alfa-cloud.zip

# Descompactando
unzip -o alfa-cloud.zip -d /opt/
mv /opt/alfa-cloud-main /opt/alfa-cloud

# Permissões
chmod -R 755 /opt/alfa-cloud
chmod +x /opt/alfa-cloud/install_dependencies.sh

# Executando script de dependências
echo "Executando install_dependencies.sh..."
cd /opt/alfa-cloud
sudo ./install_dependencies.sh

# Verifica se docker-compose existe no projeto
if [ -f /opt/alfa-cloud/docker-compose.yml ]; then
    echo "Iniciando Docker Compose..."
    docker-compose up -d
fi

echo "=== INSTALAÇÃO COMPLETA! ==="
echo "Acesse o painel em http://<SEU-IP-OU-DOMÍNIO>:porta_configurada"
