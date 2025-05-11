#!/bin/bash

# Script de instalação do Alfa Cloud
# Executar com sudo em um servidor Ubuntu 18.04
# Baixa alfa-cloud.zip de https://github.com/sofrenoob/Gggggg/main/4/alfa-cloud.zip

# Configurações
SUBDOMAIN="alfa-cloud.avira.alfalemos.shop"  # Substitua pelo seu subdomínio
INSTALL_DIR="/var/www/alfa-cloud"
LOG_FILE="/var/log/alfa-cloud-install.log"
ZIP_URL="https://github.com/sofrenoob/Gggggg/raw/main/4/alfa-cloud.zip"  # URL corrigida do alfa-cloud.zip
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
unzip -o /tmp/alfa-cloud.zip -d /tmp/alfa-cloud-extracted >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "Erro ao extrair alfa-cloud.zip. Verifique $LOG_FILE." | tee -a "$LOG_FILE"
    exit 1
fi

# 5. Copiar arquivos para os diretórios corretos
echo "Copiando arquivos para $INSTALL_DIR..." | tee -a "$LOG_FILE"
# Assumindo que o ZIP contém uma pasta 'alfa-cloud' no topo
cp -r /tmp/alfa-cloud-extracted/alfa-cloud/backend/*.py "$INSTALL_DIR/backend/" 2>/dev/null || echo "Aviso: Nenhum arquivo .py encontrado no backend." | tee -a "$LOG_FILE"
cp -r /tmp/alfa-cloud-extracted/alfa-cloud/backend/routes/*.py "$INSTALL_DIR/backend/routes/" 2>/dev/null || echo "Aviso: Nenhum arquivo .py encontrado em routes." | tee -a "$LOG_FILE"
cp -r /tmp/alfa-cloud-extracted/alfa-cloud/backend/templates/*.html "$INSTALL_DIR/backend/templates/" 2>/dev/null || echo "Aviso: Nenhum arquivo .html encontrado em templates." | tee -a "$LOG_FILE"
cp -r /tmp/alfa-cloud-extracted/alfa-cloud/backend/static/css/*.css "$INSTALL_DIR/backend/static/css/" 2>/dev/null || echo "Aviso: Nenhum arquivo .css encontrado em static/css." | tee -a "$LOG_FILE"
cp -r /tmp/alfa-cloud-extracted/alfa-cloud/backend/static/js/*.js "$INSTALL_DIR/backend/static/js/" 2>/dev/null || echo "Aviso: Nenhum arquivo .js encontrado em static/js." | tee -a "$LOG_FILE"
cp -r /tmp/alfa-cloud-extracted/alfa-cloud/backend/static/images/* "$INSTALL_DIR/backend/static/images/" 2>/dev/null || echo "Aviso: Nenhuma imagem encontrada em static/images." | tee -a "$LOG_FILE"
cp -r /tmp/alfa-cloud-extracted/alfa-cloud/scripts/*.sh "$INSTALL_DIR/scripts/" 2>/dev/null || echo "Aviso: Nenhum script .sh encontrado." | tee -a "$LOG_FILE"
cp -r /tmp/alfa-cloud-extracted/alfa-cloud/nginx/*.conf "$INSTALL_DIR/nginx/" 2>/dev/null || echo "Aviso: Nenhum arquivo .conf encontrado em nginx." | tee -a "$LOG_FILE"
cp /tmp/alfa-cloud-extracted/alfa-cloud/README.md "$INSTALL_DIR/" 2>/dev/null || echo "Aviso: Nenhum README.md encontrado." | tee -a "$LOG_FILE"
if [ $? -ne 0 ]; then
    echo "Erro ao copiar arquivos. Verifique $LOG_FILE e a estrutura do ZIP." | tee -a "$LOG_FILE"
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

# 8. Criar app.py simplificado
echo "Criando app.py..." | tee -a "$LOG_FILE"
cat <<EOT > "$INSTALL_DIR/backend/app.py"
from flask import Flask, render_template, redirect, url_for, request, flash
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
from flask_sqlalchemy import SQLAlchemy
from config import Config
from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, SubmitField
from wtforms.validators import DataRequired

app = Flask(__name__)
app.config.from_object(Config)
db = SQLAlchemy(app)

# Configurar Flask-Login
login_manager = LoginManager(app)
login_manager.login_view = 'login'

# Importar modelos
from models import User

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

# Formulário de login
class LoginForm(FlaskForm):
    username = StringField('Usuário', validators=[DataRequired()])
    password = PasswordField('Senha', validators=[DataRequired()])
    submit = SubmitField('Entrar')

# Rotas
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    form = LoginForm()
    if form.validate_on_submit():
        user = User.query.filter_by(username=form.username.data).first()
        if user and user.check_password(form.password.data) and user.is_admin:
            login_user(user)
            return redirect(url_for('index'))
        flash('Usuário ou senha inválidos, ou não é administrador.')
    return render_template('login.html', form=form)

@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('index'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
EOT

# 9. Criar config.py
echo "Criando config.py..." | tee -a "$LOG_FILE"
cat <<EOT > "$INSTALL_DIR/backend/config.py"
import os

class Config:
    SECRET_KEY = 'sua-chave-secreta-aqui-mude-isso'
    SQLALCHEMY_DATABASE_URI = 'sqlite:///{}database/alfa_cloud.db'.format(os.path.dirname(os.path.abspath(__file__)) + '/..')
    SQLALCHEMY_TRACK_MODIFICATIONS = False
EOT

# 10. Criar models.py
echo "Criando models.py..." | tee -a "$LOG_FILE"
cat <<EOT > "$INSTALL_DIR/backend/models.py"
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime

db = SQLAlchemy()

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    password_hash = db.Column(db.String(128), nullable=False)
    expiry_date = db.Column(db.DateTime, nullable=False)
    connection_limit = db.Column(db.Integer, default=1)
    is_admin = db.Column(db.Boolean, default=False)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)
EOT

# 11. Gerar SECRET_KEY para config.py
echo "Gerando SECRET_KEY..." | tee -a "$LOG_FILE"
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(24))")
sed -i "s/sua-chave-secreta-aqui-mude-isso/$SECRET_KEY/" "$INSTALL_DIR/backend/config.py"
if [ $? -ne 0 ]; then
    echo "Erro ao configurar SECRET_KEY. Verifique $LOG_FILE." | tee -a "$LOG_FILE"
    exit 1
fi

# 12. Inicializar banco de dados
echo "Inicializando banco de dados SQLite..." | tee -a "$LOG_FILE"
cat <<EOT > /tmp/init_db.py
import sys
import os
sys.path.append(os.path.abspath('$INSTALL_DIR/backend'))
try:
    from app import app, db
    with app.app_context():
        db.create_all()
    print("Banco de dados inicializado com sucesso.")
except ImportError as e:
    print(f"Erro de importação: {e}")
    raise
except Exception as e:
    print(f"Erro durante inicialização: {e}")
    raise
EOT

cd "$INSTALL_DIR/backend"
if [ -f "app.py" ]; then
    echo "Arquivo app.py encontrado em $INSTALL_DIR/backend." | tee -a "$LOG_FILE"
else
    echo "Erro: app.py não encontrado em $INSTALL_DIR/backend. Verifique a estrutura do ZIP." | tee -a "$LOG_FILE"
    exit 1
fi
python3 /tmp/init_db.py 2>&1 | tee -a "$LOG_FILE"
if [ $? -ne 0 ]; then
    echo "Erro ao inicializar banco de dados. Verifique $LOG_FILE. Conteúdo do diretório: $(ls -la)" | tee -a "$LOG_FILE"
    exit 1
fi
rm /tmp/init_db.py
chown www-data:www-data "$INSTALL_DIR/database/alfa_cloud.db"
chmod 644 "$INSTALL_DIR/database/alfa_cloud.db"

# 13. Criar usuário administrador
echo "Criando usuário administrador..." | tee -a "$LOG_FILE"
cat <<EOT > /tmp/create_admin.py
import sys
import os
sys.path.append(os.path.abspath('$INSTALL_DIR/backend'))
try:
    from app import app, db
    from models import User
    from datetime import datetime
    with app.app_context():
        admin = User(username='admin', expiry_date=datetime.strptime('2099-12-31', '%Y-%m-%d'), connection_limit=10, is_admin=True)
        admin.set_password('$ADMIN_PASSWORD')
        db.session.add(admin)
        db.session.commit()
    print("Usuário administrador criado com sucesso.")
except ImportError as e:
    print(f"Erro de importação: {e}")
    raise
except Exception as e:
    print(f"Erro durante criação do administrador: {e}")
    raise
EOT

cd "$INSTALL_DIR/backend"
python3 /tmp/create_admin.py 2>&1 | tee -a "$LOG_FILE"
if [ $? -ne 0 ]; then
    echo "Erro ao criar usuário administrador. Verifique $LOG_FILE. Conteúdo do diretório: $(ls -la)" | tee -a "$LOG_FILE"
    exit 1
fi
rm /tmp/create_admin.py

# 14. Criar template de login
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
    {{ form.hidden_tag() }}
    <div class="form-group">
        <label for="username">Usuário</label>
        {{ form.username(class="form-control", required=True) }}
    </div>
    <div class="form-group">
        <label for="password">Senha</label>
        {{ form.password(class="form-control", required=True) }}
    </div>
    {{ form.submit(class="btn btn-primary") }}
</form>
{% endblock %}
EOT

# 15. Executar scripts de configuração
echo "Executando scripts de configuração..." | tee -a "$LOG_FILE"
for script in setup_vpn.sh setup_proxy.sh setup_services.sh setup_firewall.sh; do
    echo "Executando $script..." | tee -a "$LOG_FILE"
    "$INSTALL_DIR/scripts/$script" >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo "Erro ao executar $script. Verifique $LOG_FILE." | tee -a "$LOG_FILE"
        exit 1
    fi
done

# 16. Configurar Nginx
echo "Configurando Nginx..." | tee -a "$LOG_FILE"
sed -i "s/alfa-cloud.avira.alfalemos.shop/$SUBDOMAIN/" "$INSTALL_DIR/nginx/alfa-cloud.conf"
ln -s "$INSTALL_DIR/nginx/alfa-cloud.conf" /etc/nginx/sites-enabled/
nginx -t >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "Erro na configuração do Nginx. Verifique $LOG_FILE." | tee -a "$LOG_FILE"
    exit 1
fi

# 17. Configurar SSL com Certbot
echo "Configurando SSL com Certbot..." | tee -a "$LOG_FILE"
certbot --nginx -d "$SUBDOMAIN" --non-interactive --agree-tos --email alfalemos21@gmail.com >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "Erro ao configurar SSL. Verifique $LOG_FILE." | tee -a "$LOG_FILE"
    exit 1
fi
systemctl reload nginx >> "$LOG_FILE" 2>&1

# 18. Configurar Gunicorn como serviço
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

# 19. Verificar serviços
echo "Verificando serviços..." | tee -a "$LOG_FILE"
for service in openvpn squid websocket badvpn slowdns nginx gunicorn; do
    if systemctl is-active --quiet "$service"; then
        echo "$service está ativo." | tee -a "$LOG_FILE"
    else
        echo "Erro: $service não está ativo. Verifique com 'journalctl -u $service'." | tee -a "$LOG_FILE"
        exit 1
    fi
done

# 20. Finalizar
echo "Instalação concluída com sucesso!" | tee -a "$LOG_FILE"
echo "Acesse a aplicação em https://$SUBDOMAIN" | tee -a "$LOG_FILE"
echo "Acesse o painel de admin em https://$SUBDOMAIN/login" | tee -a "$LOG_FILE"
echo "Usuário: admin | Senha: $ADMIN_PASSWORD" | tee -a "$LOG_FILE"
echo "Logs disponíveis em $LOG_FILE"
