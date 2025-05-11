#!/bin/bash

# Script de instalação do Alfa Cloud
# Executar com sudo em um servidor Ubuntu 18.04
# Baixa alfa-cloud.zip de https://github.com/sofrenoob/Gggggg/raw/main/4/alfa-cloud.zip

# Configurações
SUBDOMAIN="alfa-cloud.avira.alfalemos.shop"  # Substitua pelo seu subdomínio
INSTALL_DIR="/var/www/alfa-cloud"
LOG_FILE="/var/log/alfa-cloud-install.log"
ZIP_URL="https://github.com/sofrenoob/Gggggg/raw/main/4/alfa-cloud.zip"  # URL do alfa-cloud.zip
ADMIN_PASSWORD="Admin123!"  # Senha do usuário admin (altere se desejar)

# Verificar se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
    echo "Este script precisa ser executado como root. Use sudo." | tee -a "$LOG_FILE"
    exit 1
fi

# Criar arquivo de log
echo "Iniciando instalação do Alfa Cloud em $(date)" > "$LOG_FILE"

# 1. Atualizar o sistema
echo "Atualizando o sistema..." | tee -a "$LOG_FILE"
apt update && apt upgrade -y >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "Erro ao atualizar o sistema. Verifique $LOG_FILE." | tee -a "$LOG_FILE"
    exit 1
fi

# 2. Instalar dependências básicas
echo "Instalando dependências básicas..." | tee -a "$LOG_FILE"
apt install -y python3 python3-pip nginx sqlite3 git ufw fail2ban curl unzip cmake build-essential nodejs npm certbot python3-certbot-nginx >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "Erro ao instalar dependências. Verifique $LOG_FILE." | tee -a "$LOG_FILE"
    exit 1
fi

# 3. Criar diretórios do projeto
echo "Criando estrutura de diretórios em $INSTALL_DIR..." | tee -a "$LOG_FILE"
mkdir -p "$INSTALL_DIR"/{backend/{routes,static/{css,js,images},templates},scripts,nginx,database}
if [ $? -ne 0 ]; then
    echo "Erro ao criar diretórios. Verifique $LOG_FILE." | tee -a "$LOG_FILE"
    exit 1
fi

# 4. Baixar e extrair alfa-cloud.zip
echo "Baixando alfa-cloud.zip de $ZIP_URL..." | tee -a "$LOG_FILE"
curl -L "$ZIP_URL" -o /tmp/alfa-cloud.zip >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "Erro ao baixar alfa-cloud.zip. Verifique a URL ou conexão." | tee -a "$LOG_FILE"
    exit 1
fi

echo "Extraindo alfa-cloud.zip..." | tee -a "$LOG_FILE"
unzip /tmp/alfa-cloud.zip -d /tmp/alfa-cloud >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "Erro ao extrair alfa-cloud.zip. Verifique $LOG_FILE." | tee -a "$LOG_FILE"
    exit 1
fi

# 5. Copiar arquivos para os diretórios corretos
echo "Copiando arquivos para $INSTALL_DIR..." | tee -a "$LOG_FILE"
cp -r /tmp/alfa-cloud/backend/*.py "$INSTALL_DIR/backend/"
cp -r /tmp/alfa-cloud/backend/routes/*.py "$INSTALL_DIR/backend/routes/"
cp -r /tmp/alfa-cloud/backend/templates/*.html "$INSTALL_DIR/backend/templates/"
cp -r /tmp/alfa-cloud/backend/static/css/*.css "$INSTALL_DIR/backend/static/css/"
cp -r /tmp/alfa-cloud/backend/static/js/*.js "$INSTALL_DIR/backend/static/js/"
cp -r /tmp/alfa-cloud/backend/static/images/* "$INSTALL_DIR/backend/static/images/" 2>/dev/null
cp -r /tmp/alfa-cloud/scripts/*.sh "$INSTALL_DIR/scripts/"
cp -r /tmp/alfa-cloud/nginx/*.conf "$INSTALL_DIR/nginx/"
cp /tmp/alfa-cloud/README.md "$INSTALL_DIR/" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Erro ao copiar arquivos. Verifique $LOG_FILE." | tee -a "$LOG_FILE"
    exit 1
fi

# 6. Configurar permissões
echo "Configurando permissões..." | tee -a "$LOG_FILE"
chown -R www-data:www-data "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/scripts/"*.sh
if [ $? -ne 0 ]; then
    echo "Erro ao configurar permissões. Verifique $LOG_FILE." | tee -a "$LOG_FILE"
    exit 1
fi

# 7. Instalar dependências Python
echo "Instalando dependências Python..." | tee -a "$LOG_FILE"
cd "$INSTALL_DIR/backend"
pip3 install flask flask-sqlalchemy gunicorn flask-login flask-wtf >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "Erro ao instalar dependências Python. Verifique $LOG_FILE." | tee -a "$LOG_FILE"
    exit 1
fi

# 8. Gerar SECRET_KEY para config.py
echo "Gerando SECRET_KEY..." | tee -a "$LOG_FILE"
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(24))")
sed -i "s/sua-chave-secreta-aqui-mude-isso/$SECRET_KEY/" "$INSTALL_DIR/backend/config.py"
if [ $? -ne 0 ]; then
    echo "Erro ao configurar SECRET_KEY. Verifique $LOG_FILE." | tee -a "$LOG_FILE"
    exit 1
fi

# 9. Inicializar banco de dados
echo "Inicializando banco de dados SQLite..." | tee -a "$LOG_FILE"
python3 -c "from app import app, db; with app.app_context(): db.create_all()" >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "Erro ao inicializar banco de dados. Verifique $LOG_FILE." | tee -a "$LOG_FILE"
    exit 1
fi
chown www-data:www-data "$INSTALL_DIR/database/alfa_cloud.db"
chmod 644 "$INSTALL_DIR/database/alfa_cloud.db"

# 10. Criar usuário administrador
echo "Criando usuário administrador..." | tee -a "$LOG_FILE"
cd "$INSTALL_DIR/backend"
python3 -c "from app import app, db; from models import User; from datetime import datetime; with app.app_context(): admin = User(username='admin', expiry_date=datetime.strptime('2099-12-31', '%Y-%m-%d'), connection_limit=10, is_admin=True); admin.set_password('$ADMIN_PASSWORD'); db.session.add(admin); db.session.commit()" >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "Erro ao criar usuário administrador. Verifique $LOG_FILE." | tee -a "$LOG_FILE"
    exit 1
fi

# 11. Criar template de login
echo "Criando template de login..." | tee -a "$LOG_FILE"
cat <<EOT > "$INSTALL_DIR/backend/templates/login.html"
{% extends 'base.html' %}
{% block title %}Login{% endblock %}
{% block content %}
<h1>Login Administrador</h1>
{% with messages = get_flashed_messages() %}
    {% if messages %}
        {% for message in messages %}
            <div class="alert alert-danger">{{ message }}</div>
        {% endfor %}
    {% endif %}
{% endwith %}
<form method="POST" action="/login">
    <div class="form-group">
        <label for="username">Usuário</label>
        <input type="text" class="form-control" id="username" name="username" required>
    </div>
    <div class="form-group">
        <label for="password">Senha</label>
        <input type="password" class="form-control" id="password" name="password" required>
    </div>
    <button type="submit" class="btn btn-primary">Entrar</button>
</form>
{% endblock %}
EOT

# 12. Executar scripts de configuração
echo "Executando scripts de configuração..." | tee -a "$LOG_FILE"
for script in setup_vpn.sh setup_proxy.sh setup_services.sh setup_firewall.sh; do
    echo "Executando $script..." | tee -a "$LOG_FILE"
    "$INSTALL_DIR/scripts/$script" >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo "Erro ao executar $script. Verifique $LOG_FILE." | tee -a "$LOG_FILE"
        exit 1
    fi
done

# 13. Configurar Nginx
echo "Configurando Nginx..." | tee -a "$LOG_FILE"
sed -i "s/alfa-cloud.avira.alfalemos.shop/$SUBDOMAIN/" "$INSTALL_DIR/nginx/alfa-cloud.conf"
ln -s "$INSTALL_DIR/nginx/alfa-cloud.conf" /etc/nginx/sites-enabled/
nginx -t >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "Erro na configuração do Nginx. Verifique $LOG_FILE." | tee -a "$LOG_FILE"
    exit 1
fi

# 14. Configurar SSL com Certbot
echo "Configurando SSL com Certbot..." | tee -a "$LOG_FILE"
certbot --nginx -d "$SUBDOMAIN" --non-interactive --agree-tos --email alfalemos21@gmail.com >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "Erro ao configurar SSL. Verifique $LOG_FILE." | tee -a "$LOG_FILE"
    exit 1
fi
systemctl reload nginx >> "$LOG_FILE" 2>&1

# 15. Configurar Gunicorn como serviço
echo "Configurando Gunicorn..." | tee -a "$LOG_FILE"
cat <<EOT > /etc/systemd/system/gunicorn.service
[Unit]
Description=Gunicorn instance for Alfa Cloud
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$INSTALL_DIR/backend
ExecStart=/usr/local/bin/gunicorn -w 4 -b 127.0.0.1:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOT
systemctl daemon-reload
systemctl enable gunicorn
systemctl start gunicorn
if systemctl is-active --quiet gunicorn; then
    echo "Gunicorn iniciado com sucesso!" | tee -a "$LOG_FILE"
else
    echo "Erro ao iniciar Gunicorn. Verifique $LOG_FILE." | tee -a "$LOG_FILE"
    exit 1
fi

# 16. Verificar serviços
echo "Verificando serviços..." | tee -a "$LOG_FILE"
for service in openvpn squid websocket badvpn slowdns nginx gunicorn; do
    if systemctl is-active --quiet "$service"; then
        echo "$service está ativo." | tee -a "$LOG_FILE"
    else
        echo "Erro: $service não está ativo. Verifique com 'journalctl -u $service'." | tee -a "$LOG_FILE"
        exit 1
    fi
done

# 17. Finalizar
echo "Instalação concluída com sucesso!" | tee -a "$LOG_FILE"
echo "Acesse a aplicação em https://$SUBDOMAIN" | tee -a "$LOG_FILE"
echo "Acesse o painel de admin em https://$SUBDOMAIN/login" | tee -a "$LOG_FILE"
echo "Usuário: admin | Senha: $ADMIN_PASSWORD" | tee -a "$LOG_FILE"
echo "Logs disponíveis em $LOG_FILE"
