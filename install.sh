#!/bin/bash

echo "Atualizando sistema..."
apt update && apt upgrade -y

echo "Instalando dependências..."
apt install -y python3 python3-pip sqlite3
pip3 install flask

echo "Criando diretórios do painel..."
mkdir -p /root/proxy_panel/templates
mkdir -p /root/proxy_panel/static

echo "Criando app.py..."
cat << 'EOF' > /root/proxy_panel/app.py
from flask import Flask, render_template, request, redirect, url_for
import sqlite3

app = Flask(__name__)

def init_db():
    conn = sqlite3.connect('proxy.db')
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS logs (id INTEGER PRIMARY KEY AUTOINCREMENT, message TEXT)''')
    conn.commit()
    conn.close()

@app.route('/')
def login():
    return render_template('login.html')

@app.route('/dashboard')
def dashboard():
    conn = sqlite3.connect('proxy.db')
    c = conn.cursor()
    c.execute('SELECT * FROM logs')
    logs = c.fetchall()
    conn.close()
    return render_template('dashboard.html', logs=logs)

@app.route('/add_log', methods=['POST'])
def add_log():
    message = request.form['message']
    conn = sqlite3.connect('proxy.db')
    c = conn.cursor()
    c.execute('INSERT INTO logs (message) VALUES (?)', (message,))
    conn.commit()
    conn.close()
    return redirect(url_for('dashboard'))

if __name__ == '__main__':
    init_db()
    app.run(host='0.0.0.0', port=5000)
EOF

echo "Criando db_setup.py..."
cat << 'EOF' > /root/proxy_panel/db_setup.py
import sqlite3

conn = sqlite3.connect('proxy.db')
c = conn.cursor()
c.execute('''CREATE TABLE IF NOT EXISTS logs (id INTEGER PRIMARY KEY AUTOINCREMENT, message TEXT)''')
conn.commit()
conn.close()
EOF

echo "Criando templates/login.html..."
cat << 'EOF' > /root/proxy_panel/templates/login.html
<!DOCTYPE html>
<html>
<head><title>Login</title></head>
<body>
<h2>Login</h2>
<form action="/dashboard" method="get">
  <input type="submit" value="Entrar">
</form>
</body>
</html>
EOF

echo "Criando templates/dashboard.html..."
cat << 'EOF' > /root/proxy_panel/templates/dashboard.html
<!DOCTYPE html>
<html>
<head><title>Dashboard</title></head>
<body>
<h2>Dashboard</h2>
<form action="/add_log" method="post">
  <input type="text" name="message" placeholder="Nova log">
  <input type="submit" value="Adicionar">
</form>
<ul>
{% for log in logs %}
  <li>{{ log[1] }}</li>
{% endfor %}
</ul>
</body>
</html>
EOF

echo "Criando templates/logs.html..."
cat << 'EOF' > /root/proxy_panel/templates/logs.html
<!DOCTYPE html>
<html>
<head><title>Logs</title></head>
<body>
<h2>Logs</h2>
<ul>
{% for log in logs %}
  <li>{{ log[1] }}</li>
{% endfor %}
</ul>
</body>
</html>
EOF

echo "Criando static/style.css..."
cat << 'EOF' > /root/proxy_panel/static/style.css
body { font-family: Arial, sans-serif; }
EOF

echo "Criando requirements.txt..."
cat << 'EOF' > /root/proxy_panel/requirements.txt
flask
EOF

echo "Criando systemd service..."
cat << 'EOF' > /etc/systemd/system/painelproxy.service
[Unit]
Description=Painel de Administração de Proxies
After=network.target

[Service]
User=root
WorkingDirectory=/root/proxy_panel
ExecStart=/usr/bin/python3 app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Habilitando e iniciando serviço..."
systemctl daemon-reload
systemctl enable painelproxy.service
systemctl start painelproxy.service

echo "Painel instalado e rodando na porta 5000"
