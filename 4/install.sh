#!/bin/bash

# Script de instalação para Alfa Cloud
# Requisitos: Ubuntu 18.04 ou 20.04, acesso root, domínio configurado
# Repositório: https://github.com/sofrenoob/Gggggg/raw/main/4/alfa_cloud.zip

# Função para exibir mensagens
log() {
    echo "[INFO] $1"
}

error() {
    echo "[ERROR] $1"
    exit 1
}

# Verifica se o script está sendo executado como root
if [[ $EUID -ne 0 ]]; then
    error "Este script deve ser executado como root"
fi

# Define variáveis
REPO_URL="https://github.com/sofrenoob/Gggggg/raw/main/4/alfa_cloud.zip"
APP_DIR="/alfa_cloud"
DOMAIN="avira.alfalemos.shop"
EMAIL="alfalemos21@gmail.com"
NGINX_CONF="/etc/nginx/sites-available/alfa_cloud"
NGINX_LINK="/etc/nginx/sites-enabled/alfa_cloud"

# Passo 1: Atualizar o sistema
log "Atualizando o sistema..."
apt update && apt upgrade -y || error "Falha ao atualizar o sistema."

# Passo 2: Instalar dependências do sistema
log "Instalando dependências do sistema..."
apt install -y python3 python3-pip nginx sqlite3 certbot python3-certbot-nginx git ufw unzip cmake build-essential || error "Falha ao instalar dependências."

# Passo 3: Criar diretório de instalação
log "Criando diretório $APP_DIR..."
mkdir -p $APP_DIR/{db,logs,pids,backups} || error "Falha ao criar diretórios."
cd $APP_DIR || error "Falha ao acessar $APP_DIR."

# Passo 4: Baixar e extrair o repositório
log "Baixando o repositório do Alfa Cloud..."
wget -O alfa_cloud.zip $REPO_URL || error "Falha ao baixar o repositório."
unzip alfa_cloud.zip -d $APP_DIR || error "Falha ao extrair o repositório."
rm alfa_cloud.zip || error "Falha ao remover arquivo ZIP."

# Passo 5: Ajustar permissões
log "Ajustando permissões..."
chmod -R 755 $APP_DIR/{db,logs,pids,backups,static} || error "Falha ao ajustar permissões."
chmod 600 $APP_DIR/db/alfa_cloud.db 2>/dev/null || log "Banco de dados ainda não existe, será criado."

# Passo 6: Instalar dependências Python
log "Instalando dependências Python..."
pip3 install -r "$APP_DIR/requirements.txt" || error "Falha ao instalar dependências Python."
pip3 install gunicorn || error "Falha ao instalar Gunicorn."

# Passo 7: Configurar o banco de dados
log "Configurando banco de dados..."
if [ ! -d "$APP_DIR/db" ]; then
    mkdir -p "$APP_DIR/db" || error "Falha ao criar diretório $APP_DIR/db."
fi
if [ -f "$APP_DIR/db/create_db.sql" ]; then
    sqlite3 "$APP_DIR/db/alfa_cloud.db" < "$APP_DIR/db/create_db.sql" || error "Falha ao criar o banco de dados."
    chmod 600 "$APP_DIR/db/alfa_cloud.db"
else
    error "Arquivo create_db.sql não encontrado em $APP_DIR/db/"
fi

# Passo 8: Configurar SSL com Certbot
log "Configurando certificados SSL..."
certbot --nginx -d "$DOMAIN" -d "*.$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect || error "Falha ao configurar SSL."

# Passo 9: Configurar Nginx
log "Configurando o Nginx..."
if [ -f "$APP_DIR/nginx.conf" ]; then
    cp "$APP_DIR/nginx.conf" $NGINX_CONF || error "Falha ao copiar nginx.conf."
    ln -sf $NGINX_CONF $NGINX_LINK || error "Falha ao criar link simbólico do Nginx."
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null
else
    error "Arquivo nginx.conf não encontrado em $APP_DIR."
fi

# Testar configuração do Nginx
nginx -t || error "Erro na configuração do Nginx."

# Passo 10: Configurar firewall (UFW)
log "Configurando firewall..."
ufw allow 80 || error "Falha ao permitir porta 80."
ufw allow 443 || error "Falha ao permitir porta 443."
ufw allow 22 || error "Falha ao permitir porta 22."
ufw allow 8080 || error "Falha ao permitir porta 8080."
ufw allow 7300/udp || error "Falha ao permitir porta 7300/UDP."
ufw --force enable || error "Falha ao ativar firewall."

# Passo 11: Configurar serviço Gunicorn
log "Configurando serviço Gunicorn..."
cat << EOF > /etc/systemd/system/alfa_cloud.service
[Unit]
Description=Alfa Cloud Gunicorn Service
After=network.target

[Service]
User=root
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/gunicorn -w 4 -b 0.0.0.0:5000 app:app
Restart=always
StandardOutput=append:/$APP_DIR/logs/app.log
StandardError=append:/$APP_DIR/logs/app.log

[Install]
WantedBy=multi-user.target
EOF

# Ativar e iniciar o serviço
systemctl enable alfa_cloud.service || error "Falha ao ativar o serviço."
systemctl start alfa_cloud.service || error "Falha ao iniciar o serviço."

# Passo 12: Configurar BadVPN
log "Configurando BadVPN..."
if ! command -v badvpn-udpgw &> /dev/null; then
    git clone https://github.com/ambrop72/badvpn.git /tmp/badvpn || error "Falha ao clonar repositório BadVPN."
    cd /tmp/badvpn
    cmake . && make && make install || error "Falha ao compilar/instalar BadVPN."
    cd -
    rm -rf /tmp/badvpn
fi

# Criar serviço systemd para BadVPN
cat << EOF > /etc/systemd/system/badvpn.service
[Unit]
Description=BadVPN UDP Gateway
After=network.target

[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable badvpn.service || error "Falha ao ativar serviço BadVPN."
systemctl start badvpn.service || error "Falha ao iniciar serviço BadVPN."

# Passo 13: Reiniciar Nginx
log "Reiniciando Nginx..."
systemctl restart nginx || error "Falha ao reiniciar Nginx."

# Passo 14: Verificar status
log "Verificando status dos serviços..."
echo "-----------------------------------------------------"
echo "Status do Alfa Cloud (Gunicorn):"
systemctl status alfa_cloud.service --no-pager
echo "-----------------------------------------------------"
echo "Status do BadVPN:"
systemctl status badvpn.service --no-pager
echo "-----------------------------------------------------"
echo "Status do Nginx:"
systemctl status nginx --no-pager
echo "-----------------------------------------------------"

# Passo 15: Informações finais
log "Instalação concluída com sucesso!"
echo "-----------------------------------------------------"
echo "Acesse o painel em: https://$DOMAIN/admin/login"
echo "Usuário padrão: admin"
echo "Senha padrão: admin123"
echo "Logs: $APP_DIR/logs/app.log"
echo "Banco de dados: $APP_DIR/db/alfa_cloud.db"
echo "-----------------------------------------------------"
echo "Recomendações:"
echo "- Altere a senha padrão em $APP_DIR/app/config.py."
echo "- Faça backup regular do banco de dados ($APP_DIR/db/alfa_cloud.db)."
echo "- Teste subdomínios com $APP_DIR/scripts/subdomain_setup.sh."
echo "-----------------------------------------------------"

exit 0
