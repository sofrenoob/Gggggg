#!/bin/bash

echo "Atualizando o sistema..."
apt-get update && apt-get upgrade -y

echo "Instalando dependências..."
apt-get install -y python3 python3-pip unzip

echo "Instalando dependências Python..."
pip3 install flask

echo "Criando diretório do painel..."
mkdir -p /root/proxy_panel/templates
mkdir -p /root/proxy_panel/static

echo "Criando app.py..."
cat << 'EOF' > /root/proxy_panel/app.py
from flask import Flask, render_template, request, redirect, url_for
import sqlite3

app = Flask(__name__)

def get_db_connection():
    conn = sqlite3.connect('/root/proxy_panel/proxy.db')
    conn.row_factory = sqlite3.Row
    return conn

@app.route('/', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        if username == 'admin' and password == 'admin':
            return redirect(url_for('dashboard'))
        else:
            return 'Credenciais inválidas.'
    return render_template('login.html')

@app.route('/dashboard')
def dashboard():
    conn = get_db_connection()
    logs = conn.execute('SELECT * FROM logs').fetchall()
    conn.close()
    return render_template('dashboard.html', logs=logs)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

echo "Criando db_setup.py..."
cat << 'EOF' > /root/proxy_panel/db_setup.py
import sqlite3

conn = sqlite3.connect('/root/proxy_panel/proxy.db')
c = conn.cursor()

c.execute('''
CREATE TABLE IF NOT EXISTS logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    data TEXT NOT NULL
)
''')

conn.commit()
conn.close()
EOF

echo "Criando requirements.txt..."
echo "flask" > /root/proxy_panel/requirements.txt

echo "Criando templates/login.html..."
cat << 'EOF' > /root/proxy_panel/templates/login.html
<!doctype html>
<html>
<head>
    <title>Login</title>
    <link rel="stylesheet" href="/static/style.css">
</head>
<body>
<h2>Login</h2>
<form method="POST">
    <input type="text" name="username" placeholder="Usuário"><br>
    <input type="password" name="password" placeholder="Senha"><br>
    <input type="submit" value="Entrar">
</form>
</body>
</html>
EOF

echo "Criando templates/dashboard.html..."
cat << 'EOF' > /root/proxy_panel/templates/dashboard.html
<!doctype html>
<html>
<head>
    <title>Dashboard</title>
    <link rel="stylesheet" href="/static/style.css">
</head>
<body>
<h2>Dashboard</h2>
<ul>
{% for log in logs %}
    <li>{{ log.data }}</li>
{% endfor %}
</ul>
</body>
</html>
EOF

echo "Criando templates/logs.html..."
cat << 'EOF' > /root/proxy_panel/templates/logs.html
<!doctype html>
<html>
<head>
    <title>Logs</title>
</head>
<body>
<h2>Logs</h2>
</body>
</html>
EOF

echo "Criando static/style.css..."
cat << 'EOF' > /root/proxy_panel/static/style.css
body { font-family: Arial, sans-serif; background-color: #f2f2f2; text-align: center; }
form { margin: 20px auto; padding: 20px; background: #fff; display: inline-block; }
input { margin: 5px; padding: 10px; }
EOF

echo "Executando db_setup.py para criar o banco..."
python3 /root/proxy_panel/db_setup.py

echo "Criando serviço systemd..."
cat << 'EOF' > /etc/systemd/system/painelproxy.service
[Unit]
Description=Painel de Administração de Proxies
After=network.target

[Service]
ExecStart=/usr/bin/python3 /root/proxy_panel/app.py
WorkingDirectory=/root/proxy_panel
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

echo "Ativando e iniciando serviço..."
systemctl daemon-reload
systemctl enable painelproxy.service
systemctl start painelproxy.service

echo "Painel instalado e rodando na porta 5000!"
