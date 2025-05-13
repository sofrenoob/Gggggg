#!/usr/bin/env bash
set -e
PROJ=alfa-cloud-panel
ZIP=${PROJ}.zip
echo ">>> Gerando estrutura ${PROJ}"
rm -rf $PROJ $ZIP
mkdir -p $PROJ/{app/{routes,templates,static/css,static/img},docker/{nginx,scripts},charts/alfa-cloud/templates,tests}

# ------------------------------------------------------------------
# requirements.txt
cat > $PROJ/requirements.txt <<'EOF'
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

# ------------------------------------------------------------------
# app/__init__.py
mkdir -p $PROJ/app
cat > $PROJ/app/__init__.py <<'EOF'
from flask import Flask, g, request
from .config import Config
from .extensions import db, login_manager, migrate, bcrypt, socketio, \
                       csrf, babel, limiter, metrics, principal
from .routes import register_blueprints

def create_app(config_class=Config):
    app = Flask(__name__,
                static_folder='static',
                template_folder='templates')
    app.config.from_object(config_class)

    # Extensões
    db.init_app(app); migrate.init_app(app, db)
    login_manager.init_app(app); bcrypt.init_app(app)
    socketio.init_app(app, cors_allowed_origins="*")
    csrf.init_app(app); babel.init_app(app)
    limiter.init_app(app); metrics.init_app(app); principal.init_app(app)

    # Tenant simples via header
    @app.before_request
    def set_tenant():
        g.tenant_id = request.headers.get('X-Tenant', 'default')

    # Cabeçalhos de segurança
    @app.after_request
    def secure(resp):
        resp.headers['X-Frame-Options'] = 'DENY'
        resp.headers['Content-Security-Policy'] = "default-src 'self'"
        resp.headers['Referrer-Policy'] = 'no-referrer'
        return resp

    register_blueprints(app)
    return app
EOF

# ------------------------------------------------------------------
# app/config.py
cat > $PROJ/app/config.py <<'EOF'
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

# ------------------------------------------------------------------
# app/extensions.py
cat > $PROJ/app/extensions.py <<'EOF'
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

# ------------------------------------------------------------------
# app/models.py
cat > $PROJ/app/models.py <<'EOF'
from .extensions import db, bcrypt
from flask_login import UserMixin
from datetime import date

roles_users = db.Table('roles_users',
    db.Column('user_id', db.Integer, db.ForeignKey('admin.id')),
    db.Column('role_id', db.Integer, db.ForeignKey('role.id'))
)

class Role(db.Model):
    id   = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(30), unique=True)

class Admin(db.Model, UserMixin):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(30), unique=True, nullable=False)
    _password = db.Column(db.String(128), nullable=False)
    roles = db.relationship('Role', secondary=roles_users)

    @property
    def password(self): raise AttributeError
    @password.setter
    def password(self, plain): self._password = bcrypt.generate_password_hash(plain).decode()
    def verify(self, plain):   return bcrypt.check_password_hash(self._password, plain)

class SshUser(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(30), unique=True, nullable=False)
    password = db.Column(db.String(60), nullable=False)
    validade = db.Column(db.Date, default=date.today)
    limite   = db.Column(db.Integer, default=1)
    ativo    = db.Column(db.Boolean, default=True)

class Proxy(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    ip = db.Column(db.String(45)); porta = db.Column(db.Integer)
    protocolo = db.Column(db.String(15))
    status = db.Column(db.String(15), default="Desativado")
EOF

# ------------------------------------------------------------------
# app/routes/__init__.py
cat > $PROJ/app/routes/__init__.py <<'EOF'
from importlib import import_module

def register_blueprints(app):
    for name in ('auth', 'dashboard', 'users', 'proxies', 'services', 'live'):
        mod = import_module(f'app.routes.{name}')
        app.register_blueprint(mod.bp)
EOF

# ------------------------------------------------------------------
# app/routes/auth.py
cat > $PROJ/app/routes/auth.py <<'EOF'
from flask import Blueprint, render_template, redirect, url_for, flash
from flask_login import login_user, logout_user
from ..extensions import db, limiter
from ..models import Admin
from ..forms import LoginForm

bp = Blueprint('auth', __name__, url_prefix='/admin')

@bp.route('/login', methods=['GET','POST'])
@limiter.limit("5/minute")
def login():
    form = LoginForm()
    if form.validate_on_submit():
        admin = Admin.query.filter_by(username=form.username.data).first()
        if admin and admin.verify(form.password.data):
            login_user(admin)
            return redirect(url_for('dashboard.index'))
        flash('Credenciais inválidas')
    return render_template('login.html', form=form)

@bp.route('/logout')
def logout(): logout_user(); return redirect(url_for('auth.login'))
EOF

# ------------------------------------------------------------------
# app/forms.py
cat > $PROJ/app/forms.py <<'EOF'
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
    ip   = StringField('IP', validators=[DataRequired()])
    porta = IntegerField('Porta', validators=[DataRequired()])
    protocolo = SelectField('Protocolo',
        choices=['WebSocket','Socks','Ssltunnel','Sslproxy','Badvpn','Udpvpn','Slowdns','Direct'])

class ServiceForm(FlaskForm):
    servico = SelectField('Serviço',
        choices=['Websocket','Socks','Ssltunnel','Sslproxy','Badvpn','Udpvpn','Slowdns','Direct'])
    acao    = SelectField('Ação', choices=['Iniciar','Parar','Reiniciar'])
    porta   = IntegerField('Porta', validators=[DataRequired()])
EOF

# ------------------------------------------------------------------
# simples dashboard blueprint
cat > $PROJ/app/routes/dashboard.py <<'EOF'
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

# ------------------------------------------------------------------
# outros blueprints (stubs rápidos)
touch $PROJ/app/routes/{users,proxies,services,live}.py
cat > $PROJ/app/routes/users.py <<'EOF'
from flask import Blueprint
bp = Blueprint('users',__name__,url_prefix='/admin/users')
EOF
cat > $PROJ/app/routes/proxies.py <<'EOF'
from flask import Blueprint
bp = Blueprint('proxies',__name__,url_prefix='/admin/proxies')
EOF
cat > $PROJ/app/routes/services.py <<'EOF'
from flask import Blueprint
bp = Blueprint('services',__name__,url_prefix='/admin/services')
EOF
cat > $PROJ/app/routes/live.py <<'EOF'
from flask_socketio import emit
from ..extensions import socketio
bp = Blueprint('live',__name__)
@socketio.on('subscribe_active')
def send(_): emit('active_count', {'conexoes':0})
EOF

# ------------------------------------------------------------------
# templates mínimos
cat > $PROJ/app/templates/base.html <<'EOF'
<!doctype html><html lang="pt-br" data-bs-theme="dark">
<head>
<meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
<title>{% block title %}Alfa Cloud{% endblock %}</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel=stylesheet>
</head>
<body class="bg-dark text-white">
<nav class="navbar navbar-dark bg-primary"><div class=container-fluid>
<a class="navbar-brand" href="{{ url_for('dashboard.index') }}">Alfa<br>Cloud</a>
</div></nav>
<div class=container>{% block content %}{% endblock %}</div>
</body></html>
EOF
cat > $PROJ/app/templates/login.html <<'EOF'
{% extends 'base.html' %}{% block content %}
<form method=post class="mt-5 col-md-4 mx-auto">
{{ form.hidden_tag() }}
<h3 class=text-center>Login do Administrador</h3>
<div class=mb-3>{{ form.username.label }}{{ form.username(class="form-control") }}</div>
<div class=mb-3>{{ form.password.label }}{{ form.password(class="form-control") }}</div>
<button class="btn btn-success w-100">Entrar</button>
</form>{% endblock %}
EOF
cat > $PROJ/app/templates/dashboard.html <<'EOF'
{% extends 'base.html' %}{% block content %}
<h2>Painel do Administrador</h2>
<div class="row text-center">
  <div class="col-4"><h3 id="count-users">{{ users }}</h3>Usuários</div>
  <div class="col-4"><h3 id="count-proxies">{{ proxies }}</h3>Proxies</div>
  <div class="col-4"><h3 id="count-conexoes">0</h3>Conexões</div>
</div>
<script src="https://cdn.socket.io/4.7.5/socket.io.min.js"></script>
<script>
const ioSock = io();
ioSock.emit('subscribe_active');
ioSock.on('active_count', d=>{document.getElementById('count-conexoes').innerText=d.conexoes;});
</script>
{% endblock %}
EOF

# ------------------------------------------------------------------
# Dockerfile
cat > $PROJ/Dockerfile <<'EOF'
FROM python:3.12-slim AS base
ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 FLASK_APP=app:create_app
WORKDIR /app
COPY requirements.txt .
RUN apt-get update && apt-get install -y build-essential gcc netcat-traditional \
 && pip install -r requirements.txt \
 && apt-get purge -y build-essential gcc && apt-get autoremove -y && apt-get clean
COPY . .
RUN adduser --disabled-password --uid 1001 appuser
USER appuser
CMD ["python","-m","flask","run","--host","0.0.0.0","--port","8000"]
EOF

# ------------------------------------------------------------------
# docker-compose.yml
cat > $PROJ/docker-compose.yml <<'EOF'
version: "3.9"
services:
  web:
    build: .
    environment:
      - FLASK_ENV=production
    ports: ["8000:8000"]
    volumes: ["./docker/scripts:/usr/local/bin"]
    command: >
      bash -c "flask db upgrade &&
               python -m flask run --host 0.0.0.0 --port 8000"
  nginx:
    image: nginx:1.25
    depends_on: [web]
    ports: ["80:80"]
    volumes:
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
EOF

# ------------------------------------------------------------------
# nginx default
mkdir -p $PROJ/docker/nginx
cat > $PROJ/docker/nginx/default.conf <<'EOF'
server {
  listen 80;
  location / { proxy_pass http://web:8000; }
}
EOF

# ------------------------------------------------------------------
# exemplo script websocket
mkdir -p $PROJ/docker/scripts
cat > $PROJ/docker/scripts/websocket.sh <<'EOF'
#!/usr/bin/env bash
echo "Script fake websocket $@"
EOF
chmod +x $PROJ/docker/scripts/websocket.sh

# ------------------------------------------------------------------
# testes
cat > $PROJ/tests/test_auth.py <<'EOF'
from app import create_app
from app.extensions import db
import pytest
@pytest.fixture
def client():
    app = create_app({'TESTING':True,'SQLALCHEMY_DATABASE_URI':'sqlite://'})
    with app.app_context(): db.create_all(); yield app.test_client()
def test_login_page(client):
    r = client.get('/admin/login'); assert r.status_code==200
EOF

# ------------------------------------------------------------------
# simple README
cat > $PROJ/README.md <<'EOF'
# Alfa Cloud Panel

## Build rápido
```bash
docker compose up --build
```
Depois crie o admin:
```bash
docker compose exec web flask shell -c "from app.extensions import db; from app.models import Admin; a=Admin(username='admin'); a.password='senha'; db.session.add(a); db.session.commit()"
```
Acesse http://localhost/admin/login
EOF

# ------------------------------------------------------------------
echo ">>> Compactando $ZIP"
zip -rq $ZIP $PROJ
echo "Pronto! Veja $ZIP"