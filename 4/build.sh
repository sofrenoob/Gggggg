
########################################################################
#  Alfa-Cloud – instalador completo                                     #
#  Gera todos os arquivos, instala Docker, cria Admin e sobe o painel   #
########################################################################
set -e

#========================== VARIÁVEIS =================================#
PROJ_DIR="/opt/alfa-cloud-panel"
APP_USER="appuser"
SECRET_KEY=$(openssl rand -hex 32)
GREEN='\e[32m'; YELLOW='\e[33m'; RED='\e[31m'; NC='\e[0m'
say()  { echo -e "${GREEN}==>${NC} $*"; }
warn() { echo -e "${YELLOW}WARN:${NC} $*"; }
die()  { echo -e "${RED}ERRO:${NC} $*" ; exit 1; }
[[ $EUID -ne 0 ]] && die "Execute como root ou sudo!"

#====================== 1. DOCKER / COMPOSE ===========================#
install_docker() {
  say "Instalando Docker ..."
  apt-get update -qq
  apt-get install -y ca-certificates curl gnupg lsb-release
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
       gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
 https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
 > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable --now docker
}

command -v docker >/dev/null 2>&1 || install_docker
command -v docker compose >/dev/null 2>&1 || apt-get install -y docker-compose-plugin

#====================== 2. USUÁRIO DO APP ============================#
id -u $APP_USER &>/dev/null || adduser --disabled-password --gecos "" $APP_USER
usermod -aG docker $APP_USER

#====================== 3. GERAR PROJETO =============================#
say "Gerando projeto em $PROJ_DIR"
rm -rf "$PROJ_DIR"
mkdir -p "$PROJ_DIR"
chown $SUDO_USER:$SUDO_USER "$PROJ_DIR"
sudo -u $SUDO_USER bash -c "cd $PROJ_DIR && mkdir -p app/{routes,templates,static/{css,img}} docker/{nginx,scripts} tests charts/alfa-cloud/templates"

#----------- função auxiliar p/ criar arquivos -----------------------#
write() { # write path <<'EOF' ... EOF
  local path="$PROJ_DIR/$1"; shift
  sudo -u $SUDO_USER bash -c "cat > '$path'" <<"$@"
}

#====================== 3.1 requirements.txt =========================#
write requirements.txt <<'EOF'
Flask==3.0.3
Flask-Login==0.6.3
Flask-WTF==1.2.1
WTForms==3.1.2
SQLAlchemy==2.0.29
Flask-Migrate==4.0.5
flask-bcrypt==1.0.1
Flask-SocketIO==6.1.5
eventlet==0.35.2
Flask-Babel==4.0.0
Flask-Principal==0.4.0
Flask-Security-Too==5.3.4
prometheus_flask_exporter==0.23.0
Flask-Limiter==3.5.0
pytest==8.2.0
pytest-socketio==0.6.0
EOF

#====================== 3.2 APP – núcleo =============================#
write app/__init__.py <<'EOF'
from flask import Flask, g, request
from .config import Config
from .extensions import (db, migrate, login_manager, bcrypt, socketio, csrf,
                         babel, limiter, metrics, principal)
from .routes import register_blueprints

def create_app(cfg=Config):
    app = Flask(__name__, static_folder='static', template_folder='templates')
    app.config.from_object(cfg)

    # Extensões
    db.init_app(app); migrate.init_app(app, db)
    login_manager.init_app(app); bcrypt.init_app(app)
    socketio.init_app(app, cors_allowed_origins="*")
    csrf.init_app(app); babel.init_app(app)
    limiter.init_app(app); metrics.init_app(app); principal.init_app(app)

    @app.before_request
    def set_tenant():
        g.tenant_id = request.headers.get('X-Tenant', 'default')

    @app.after_request
    def secure(r):
        r.headers['X-Frame-Options'] = 'DENY'
        r.headers['Content-Security-Policy'] = "default-src 'self'"
        r.headers['Referrer-Policy'] = 'no-referrer'
        return r

    register_blueprints(app)
    return app
EOF

write app/config.py <<'EOF'
import os, secrets, pathlib
BASE = pathlib.Path(__file__).parent.parent
class Config:
    SECRET_KEY = os.getenv('SECRET_KEY', secrets.token_hex(32))
    SQLALCHEMY_DATABASE_URI = os.getenv('DATABASE_URL',
        f"sqlite:///{BASE/'data.db'}")
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    WTF_CSRF_TIME_LIMIT = None
    LANGUAGES = ['pt', 'en', 'es']
EOF

write app/extensions.py <<'EOF'
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager
from flask_migrate import Migrate
from flask_bcrypt import Bcrypt
from flask_socketio import SocketIO
from flask_wtf import CSRFProtect
from flask_babel import Babel
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_principal import Principal
from prometheus_flask_exporter import PrometheusMetrics

db = SQLAlchemy()
migrate = Migrate()
login_manager = LoginManager()
bcrypt = Bcrypt()
socketio = SocketIO(async_mode="eventlet")
csrf = CSRFProtect()
babel = Babel()
limiter = Limiter(key_func=get_remote_address)
metrics = PrometheusMetrics(group_by='endpoint')
principal = Principal()
EOF

#====================== 3.3 MODELS ===================================#
write app/models.py <<'EOF'
from .extensions import db, bcrypt
from flask_login import UserMixin
from datetime import date

roles_users = db.Table('roles_users',
    db.Column('user_id', db.Integer, db.ForeignKey('admin.id')),
    db.Column('role_id', db.Integer, db.ForeignKey('role.id')))

class Role(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(30), unique=True)

class Admin(db.Model, UserMixin):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(30), unique=True, nullable=False)
    _password = db.Column(db.String(128), nullable=False)
    roles = db.relationship('Role', secondary=roles_users)

    @property
    def password(self): raise AttributeError
    @password.setter
    def password(self, plain):
        self._password = bcrypt.generate_password_hash(plain).decode()
    def verify(self, plain): return bcrypt.check_password_hash(self._password, plain)

class SshUser(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(30), unique=True, nullable=False)
    password = db.Column(db.String(60), nullable=False)
    validade = db.Column(db.Date, default=date.today)
    limite = db.Column(db.Integer, default=1)
    ativo = db.Column(db.Boolean, default=True)

class Proxy(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    ip = db.Column(db.String(45)); porta = db.Column(db.Integer)
    protocolo = db.Column(db.String(15))
    status = db.Column(db.String(15), default="Desativado")
EOF

#====================== 3.4 FORMS ====================================#
write app/forms.py <<'EOF'
from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, IntegerField, DateField, SelectField
from wtforms.validators import DataRequired, Length

class LoginForm(FlaskForm):
    username = StringField('Usuário', validators=[DataRequired()])
    password = PasswordField('Senha', validators=[DataRequired()])

class UserForm(FlaskForm):
    username = StringField('Usuário', validators=[DataRequired(), Length(max=30)])
    password = PasswordField('Senha', validators=[DataRequired()])
    validade = DateField('Validade', validators=[DataRequired()], format='%Y-%m-%d')
    limite   = IntegerField('Limite', validators=[DataRequired()])

class ProxyForm(FlaskForm):
    ip = StringField('IP', validators=[DataRequired()])
    porta = IntegerField('Porta', validators=[DataRequired()])
    protocolo = SelectField('Protocolo',
        choices=['WebSocket','Socks','Ssltunnel','Sslproxy','Badvpn','Udpvpn','Slowdns','Direct'])

class ServiceForm(FlaskForm):
    servico = SelectField('Serviço',
        choices=['Websocket','Socks','Ssltunnel','Sslproxy','Badvpn','Udpvpn','Slowdns','Direct'])
    acao    = SelectField('Ação', choices=['Iniciar','Parar','Reiniciar'])
    porta   = IntegerField('Porta', validators=[DataRequired()])
EOF

#====================== 3.5 BLUEPRINTS CORE ==========================#
write app/routes/__init__.py <<'EOF'
from importlib import import_module
def register_blueprints(app):
    for name in ('auth','dashboard','users','proxies','services','live'):
        mod = import_module(f'app.routes.{name}')
        app.register_blueprint(mod.bp)
EOF

# Authentication
write app/routes/auth.py <<'EOF'
from flask import Blueprint, render_template, redirect, url_for, flash
from flask_login import login_user, logout_user
from ..models import Admin
from ..forms import LoginForm
from ..extensions import limiter

bp = Blueprint('auth', __name__, url_prefix='/admin')

@bp.route('/login', methods=['GET','POST'])
@limiter.limit("5/minute")
def login():
    form = LoginForm()
    if form.validate_on_submit():
        user = Admin.query.filter_by(username=form.username.data).first()
        if user and user.verify(form.password.data):
            login_user(user)
            return redirect(url_for('dashboard.index'))
        flash('Credenciais inválidas')
    return render_template('login.html', form=form)

@bp.route('/logout')
def logout():
    logout_user()
    return redirect(url_for('auth.login'))
EOF

# Dashboard
write app/routes/dashboard.py <<'EOF'
from flask import Blueprint, render_template
from flask_login import login_required
from ..models import SshUser, Proxy
bp = Blueprint('dashboard', __name__, url_prefix='/admin')

@bp.route('/')
@login_required
def index():
    return render_template('dashboard.html',
        users=SshUser.query.count(),
        proxies=Proxy.query.count())
EOF

# Crud stubs
write app/routes/users.py <<'EOF'
from flask import Blueprint
bp = Blueprint('users', __name__, url_prefix='/admin/users')
# implementar CRUD real conforme necessidade
EOF
write app/routes/proxies.py <<'EOF'
from flask import Blueprint
bp = Blueprint('proxies', __name__, url_prefix='/admin/proxies')
EOF
write app/routes/services.py <<'EOF'
from flask import Blueprint
bp = Blueprint('services', __name__, url_prefix='/admin/services')
EOF

# Live socket
write app/routes/live.py <<'EOF'
from flask_socketio import emit
from ..extensions import socketio
bp = Blueprint('live', __name__)

@socketio.on('subscribe_active')
def subs(_):
    emit('active_count', {'conexoes': 0})
EOF

#====================== 3.6 TEMPLATES =================================#
write app/templates/base.html <<'EOF'
<!doctype html><html lang="pt-br" data-bs-theme="dark">
<head>
<meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
<title>{% block title %}Alfa Cloud{% endblock %}</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel=stylesheet>
</head><body class="bg-dark text-white">
<nav class="navbar navbar-dark bg-primary"><div class=container-fluid>
<a class="navbar-brand" href="{{ url_for('dashboard.index') }}">Alfa<br>Cloud</a>
{% if current_user.is_authenticated %}<a href="{{url_for('auth.logout')}}" class="btn btn-danger">Sair</a>{% endif %}
</div></nav>
<div class=container>{% with m=get_flashed_messages() %}{% if m %}
<div class="alert alert-info mt-2">{{ m[0] }}</div>{% endif %}{% endwith %}
{% block content %}{% endblock %}</div>
</body></html>
EOF

write app/templates/login.html <<'EOF'
{% extends 'base.html' %}{% block content %}
<form method=post class="mt-5 col-md-4 mx-auto">
{{ form.hidden_tag() }}
<h3 class=text-center>Login do Administrador</h3>
<div class=mb-3>{{ form.username.label }}{{ form.username(class="form-control") }}</div>
<div class=mb-3>{{ form.password.label }}{{ form.password(class="form-control") }}</div>
<button class="btn btn-success w-100">Entrar</button>
</form>{% endblock %}
EOF

write app/templates/dashboard.html <<'EOF'
{% extends 'base.html' %}{% block content %}
<h2>Painel do Administrador</h2>
<div class="row text-center">
  <div class="col-4"><h3 id="count-users">{{ users }}</h3>Usuários</div>
  <div class="col-4"><h3 id="count-proxies">{{ proxies }}</h3>Proxies</div>
  <div class="col-4"><h3 id="count-conexoes">0</h3>Conexões</div>
</div>
<script src="https://cdn.socket.io/4.7.5/socket.io.min.js"></script>
<script>
const ioSock=io();ioSock.emit('subscribe_active');
ioSock.on('active_count',d=>{document.getElementById('count-conexoes').innerText=d.conexoes});
</script>
{% endblock %}
EOF

#====================== 3.7 STATIC ====================================#
write app/static/css/styles.css <<'EOF'
body{font-family:system-ui}
EOF

#====================== 3.8 DOCKERFILE ================================#
write Dockerfile <<'EOF'
FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 FLASK_APP=app:create_app
WORKDIR /app
COPY requirements.txt .
RUN apt-get update && apt-get install -y build-essential gcc netcat-traditional \
 && pip install -r requirements.txt \
 && apt-get purge -y build-essential gcc && apt-get autoremove -y && apt-get clean
COPY . .
RUN adduser --disabled-password --uid 1001 appuser
USER appuser
CMD ["gunicorn","-k","eventlet","-w","1","-b","0.0.0.0:8000","app:create_app"]
EOF

#====================== 3.9 docker-compose ============================#
write docker-compose.yml <<'EOF'
version: "3.9"
services:
  web:
    build: .
    env_file: .env
    restart: unless-stopped
    ports: ["8000:8000"]
    volumes:
      - ./docker/scripts:/usr/local/bin
    command: >
      bash -c "flask db upgrade &&
               gunicorn -k eventlet -w 1 -b 0.0.0.0:8000 app:create_app"
  nginx:
    image: nginx:1.25
    depends_on: [web]
    ports: ["80:80"]
    volumes:
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    restart: unless-stopped
EOF

#====================== 3.10 nginx default ============================#
write docker/nginx/default.conf <<'EOF'
server {
  listen 80;
  location / { proxy_pass http://web:8000; }
}
EOF

#====================== 3.11 script de serviço ========================#
write docker/scripts/websocket.sh <<'EOF'
#!/usr/bin/env bash
echo "Script de exemplo WebSocket $@"
EOF
chmod +x "$PROJ_DIR/docker/scripts/websocket.sh"

#====================== 3.12 testes ==================================#
write tests/test_basic.py <<'EOF'
from app import create_app
from app.extensions import db
import pytest
@pytest.fixture
def client():
    app = create_app({'TESTING':True,'SQLALCHEMY_DATABASE_URI':'sqlite://'})
    with app.app_context(): db.create_all(); yield app.test_client()
def test_login(client):
    assert client.get('/admin/login').status_code==200
EOF

#====================== 4. .env ======================================#
write .env <<EOF
SECRET_KEY=$SECRET_KEY
FLASK_ENV=production
EOF

#====================== 5. sudoers p/ scripts ========================#
say "Dando sudo NOPASSWD para scripts de serviço"
echo "$APP_USER ALL=(root) NOPASSWD: /usr/local/bin/*.sh" > /etc/sudoers.d/alfa-cloud
chmod 440 /etc/sudoers.d/alfa-cloud

#====================== 6. BUILD & UP ================================#
say "Construindo containers..."
sudo -u $SUDO_USER docker compose -f "$PROJ_DIR/docker-compose.yml" build

say "Subindo containers..."
sudo -u $SUDO_USER docker compose -f "$PROJ_DIR/docker-compose.yml" up -d

# espera o gunicorn ficar de pé
sleep 8

#====================== 7. Criar admin ===============================#
read -p "Usuário ADMIN inicial: " ADMIN_USER
while true; do
  read -s -p "Senha admin: " ADMIN_PASS; echo
  read -s -p "Confirme senha: " ADMIN_PASS2; echo
  [[ "$ADMIN_PASS" == "$ADMIN_PASS2" ]] && break
  warn "Senhas não conferem."
done

say "Criando admin dentro do container..."
docker compose -f "$PROJ_DIR/docker-compose.yml" exec web \
  flask shell -c "from app.extensions import db; from app.models import Admin; \
a=Admin(username='$ADMIN_USER'); a.password='$ADMIN_PASS'; \
db.session.add(a); db.session.commit(); print('Admin criado.')"

#====================== 8. FIM =======================================#
IP=$(hostname -I | awk '{print $1}')
say "Instalação concluída!"
echo -e "${GREEN}Acesse:${NC} http://$IP/admin/login"
echo "Use usuário '$ADMIN_USER' e a senha definida."
