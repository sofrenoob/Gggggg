#!/bin/bash

# Script de instalação do Alfa Cloud
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
if [ "$EUID" -ne 0 ]; then
    error "Este script deve ser executado como root (use sudo)."
fi

# Variáveis
REPO_URL="https://github.com/sofrenoob/Gggggg/raw/main/4/alfa_cloud.zip"
INSTALL_DIR="/alfa_cloud"
DOMAIN="avira.alfalemos.shop"  # Substitua pelo seu domínio
NGINX_CONF="/etc/nginx/sites-available/alfa_cloud"
NGINX_LINK="/etc/nginx/sites-enabled/alfa_cloud"

# Passo 1: Atualizar o sistema
log "Atualizando o sistema..."
apt update && apt upgrade -y || error "Falha ao atualizar o sistema."

# Passo 2: Instalar dependências
log "Instalando dependências..."
apt install -y git unzip sqlite3 python3 python3-pip nginx certbot python3-certbot-nginx ufw || error "Falha ao instalar dependências."

# Passo 3: Criar diretório de instalação
log "Criando diretório $INSTALL_DIR..."
mkdir -p $INSTALL_DIR/{db,pids,logs,backups} || error "Falha ao criar diretórios."
cd $INSTALL_DIR || error "Falha ao acessar $INSTALL_DIR."

# Passo 4: Baixar e extrair o repositório
log "Baixando o repositório do Alfa Cloud..."
wget -O alfa_cloud.zip $REPO_URL || error "Falha ao baixar o repositório."
unzip alfa_cloud.zip -d $INSTALL_DIR || error "Falha ao extrair o repositório."
rm alfa_cloud.zip

# Passo 5: Ajustar permissões
log "Ajustando permissões..."
chmod -R 755 $INSTALL_DIR/{db,pids,logs,backups,static} || error "Falha ao ajustar permissões."
chmod 600 $INSTALL_DIR/db/alfa_cloud.db 2>/dev/null || log "Banco de dados ainda não existe, será criado."

# Passo 6: Instalar dependências Python
log "Instalando dependências Python..."
pip3 install -r $INSTALL_DIR/requirements.txt || error "Falha ao instalar dependências Python."

# Passo 7: Configurar o banco de dados
log "Configurando o banco de dados..."
if [ -f "$INSTALL_DIR/db/create_db.sql" ]; then
    sqlite3 $INSTALL_DIR/db/alfa_cloud.db < $INSTALL_DIR/db/create_db.sql || error "Falha ao criar o banco de dados."
else
    error "Arquivo create_db.sql não encontrado em $INSTALL_DIR/db."
fi

# Passo 8: Configurar Nginx
log "Configurando Nginx..."
if [ -f "$INSTALL_DIR/nginx.conf" ]; then
    cp $INSTALL_DIR/nginx.conf $NGINX_CONF || error "Falha ao copiar nginx.conf."
    ln -sf $NGINX_CONF $NGINX_LINK || error "Falha ao criar link simbólico do Nginx."
else
    error "Arquivo nginx.conf não encontrado em $INSTALL_DIR."
fi

# Testar configuração do Nginx
nginx -t || error "Erro na configuração do Nginx."

# Passo 9: Configurar SSL com Certbot
log "Configurando certificados SSL com Certbot..."
certbot --nginx -d $DOMAIN -d *.$DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN || error "Falha ao configurar SSL."

# Passo 10: Configurar firewall
log "Configurando firewall (ufw)..."
ufw allow 80 || error "Falha ao permitir porta 80."
ufw allow 443 || error "Falha ao permitir porta 443."
ufw allow 22 || error "Falha ao permitir porta 22."
ufw --force enable || error "Falha ao ativar firewall."

# Passo 11: Iniciar o serviço Flask
log "Iniciando o serviço Alfa Cloud..."
# Criar um serviço systemd para o Flask
cat << EOF > /etc/systemd/system/alfa_cloud.service
[Unit]
Description=Alfa Cloud Flask Application
After=network.target

[Service]
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/app/__init__.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Ativar e iniciar o serviço
systemctl enable alfa_cloud.service || error "Falha ao ativar o serviço."
systemctl start alfa_cloud.service || error "Falha ao iniciar o serviço."

# Passo 12: Reiniciar Nginx
log "Reiniciando Nginx..."
systemctl restart nginx || error "Falha ao reiniciar Nginx."

# Passo 13: Verificar status
log "Verificando status do serviço..."
systemctl status alfa_cloud.service --no-pager
systemctl status nginx --no-pager

# Passo 14: Informações finais
log "Instalação concluída com sucesso!"
echo "-----------------------------------------------------"
echo "Acesse o painel em: https://$DOMAIN/admin/login"
echo "Usuário padrão: admin"
echo "Senha padrão: admin123"
echo "Logs: $INSTALL_DIR/logs/"
echo "Banco de dados: $INSTALL_DIR/db/alfa_cloud.db"
echo "-----------------------------------------------------"
echo "Recomendações:"
echo "- Altere a senha padrão em $INSTALL_DIR/app/config.py."
echo "- Faça backup regular do banco de dados ($INSTALL_DIR/db/alfa_cloud.db)."
echo "- Teste subdomínios com $INSTALL_DIR/scripts/subdomain_setup.sh."
echo "-----------------------------------------------------"

exit 0
