#!/bin/bash

# Definir cores para mensagens
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # Sem cor

echo -e "${GREEN}=== Iniciando a Instalação do Projeto App Store ===${NC}"

# Verificar se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Por favor, execute este script como root (use sudo).${NC}"
    exit 1
fi

# Perguntar ao usuário o IP ou domínio
echo "Digite o IP ou domínio do servidor (ex.: 192.168.1.100 ou seu-dominio.com):"
read SERVER_ADDRESS
if [ -z "$SERVER_ADDRESS" ]; then
    echo -e "${RED}IP ou domínio não pode ser vazio!${NC}"
    exit 1
fi

# Atualizar o sistema
echo -e "${GREEN}Atualizando o sistema...${NC}"
apt update && apt upgrade -y

# Instalar dependências
echo -e "${GREEN}Instalando dependências...${NC}"
apt install python3 python3-pip nginx unzip -y
pip3 install flask flask-sqlalchemy werkzeug gunicorn

# Criar diretório do projeto e baixar o ZIP do GitHub
echo -e "${GREEN}Baixando o projeto do GitHub...${NC}"
mkdir -p /var/www/appstore
cd /var/www/appstore
wget https://github.com/sofrenoob/Gggggg/raw/main/4/5/appstore.zip -O appstore.zip
if [ $? -ne 0 ]; then
    echo -e "${RED}Erro ao baixar o arquivo ZIP do GitHub. Verifique o link ou conexão.${NC}"
    exit 1
fi

# Descompactar o ZIP
echo -e "${GREEN}Descompactando o arquivo ZIP...${NC}"
unzip appstore.zip -d /var/www/appstore
if [ $? -ne 0 ]; then
    echo -e "${RED}Erro ao descompactar o arquivo ZIP. Verifique o conteúdo.${NC}"
    exit 1
fi

# Remover o arquivo ZIP após descompactar
rm -f appstore.zip

# Criar diretórios adicionais (caso não existam após o descompactar)
echo -e "${GREEN}Criando estrutura de diretórios...${NC}"
mkdir -p /var/www/appstore/templates
mkdir -p /var/www/appstore/static/css
mkdir -p /var/www/appstore/static/js
mkdir -p /var/www/appstore/static/icons
mkdir -p /var/www/appstore/apks

# Ajustar permissões
echo -e "${GREEN}Ajustando permissões...${NC}"
chmod -R 755 /var/www/appstore
chown -R www-data:www-data /var/www/appstore

# Verificar se o arquivo app.py está presente
echo -e "${GREEN}Verificando arquivos do projeto...${NC}"
if [ ! -f "/var/www/appstore/app.py" ]; then
    echo -e "${RED}Arquivo app.py não encontrado! Verifique se o ZIP contém todos os arquivos necessários.${NC}"
    exit 1
fi

# Configurar o Nginx
echo -e "${GREEN}Configurando o Nginx...${NC}"
cat > /etc/nginx/sites-available/appstore <<EOL
server {
    listen 80;
    server_name ${SERVER_ADDRESS};

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location /static/ {
        alias /var/www/appstore/static/;
    }

    location /apks/ {
        alias /var/www/appstore/apks/;
    }
}
EOL

# Ativar a configuração do Nginx
ln -sf /etc/nginx/sites-available/appstore /etc/nginx/sites-enabled/
systemctl restart nginx

# Iniciar o servidor com Gunicorn
echo -e "${GREEN}Iniciando o servidor com Gunicorn...${NC}"
cd /var/www/appstore
gunicorn --bind 0.0.0.0:5000 app:app &

# Verificar se o Gunicorn está rodando
sleep 2
if pgrep gunicorn > /dev/null; then
    echo -e "${GREEN}Servidor iniciado com sucesso!${NC}"
    echo -e "${GREEN}Acesse o site em: http://${SERVER_ADDRESS}${NC}"
    echo -e "${GREEN}Acesse o painel admin em: http://${SERVER_ADDRESS}/login${NC}"
    echo -e "${GREEN}Credenciais padrão - Usuário: admin | Senha: admin123${NC}"
else
    echo -e "${RED}Erro ao iniciar o servidor. Verifique os logs para mais detalhes.${NC}"
    exit 1
fi

echo -e "${GREEN}Instalação concluída!${NC}"
