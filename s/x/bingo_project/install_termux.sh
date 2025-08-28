#!/bin/bash

# Atualizar o Termux
echo "Atualizando o Termux..."
pkg update && pkg upgrade -y

# Instalar pré-requisitos: Python, wget
echo "Instalando Python e wget..."
pkg install python wget -y

# Criar diretório do projeto
PROJECT_DIR=$HOME/bingo_project
mkdir -p $PROJECT_DIR/templates

# Baixar arquivos
echo "Baixando arquivos..."
cd $PROJECT_DIR
wget https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/x/bingo_project/app.py -O app.py
cd templates
wget https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/x/bingo_project/templates/admin.html -O admin.html
# Tentativa de baixar outros arquivos HTML (substitua pelos links reais se existirem)
wget https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/x/bingo_project/templates/base.html -O base.html || touch base.html
wget https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/x/bingo_project/templates/register.html -O register.html || touch register.html
wget https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/x/bingo_project/templates/login.html -O login.html || touch login.html
wget https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/x/bingo_project/templates/index.html -O index.html || touch index.html
wget https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/x/bingo_project/templates/recharge.html -O recharge.html || touch recharge.html
echo "Atenção: Se algum arquivo HTML (base.html, register.html, login.html, index.html, recharge.html) não foi baixado, crie-os manualmente em $PROJECT_DIR/templates/ com o conteúdo correto ou forneça os links reais."

# Criar e ativar ambiente virtual
cd $PROJECT_DIR
echo "Configurando ambiente virtual..."
python -m venv venv
source venv/bin/activate

# Instalar dependências
echo "Instalando dependências Python..."
pip install flask flask-sqlalchemy werkzeug apscheduler mercadopago qrcode pillow

# Configurações adicionais
echo "Edite app.py para inserir seu access token do Mercado Pago e número de WhatsApp."
echo "Exemplo: Substitua 'YOUR_ACCESS_TOKEN' em app.py pelo seu token do Mercado Pago."
echo "Exemplo: Atualize a URL do WhatsApp em app.py (ex: https://wa.me/+5511999999999)."
echo "Para expor o servidor local, instale ngrok com 'pkg install ngrok' e execute 'ngrok http 5000'."

# Executar o app para teste
echo "Executando o app... Acesse http://127.0.0.1:5000 (use ngrok para expor externamente)"
python app.py#!/bin/bash

# Atualizar o Termux
echo "Atualizando o Termux..."
pkg update && pkg upgrade -y

# Instalar pré-requisitos: Python, wget
echo "Instalando Python e wget..."
pkg install python wget -y

# Criar diretório do projeto
PROJECT_DIR=$HOME/bingo_project
mkdir -p $PROJECT_DIR/templates

# Baixar arquivos
echo "Baixando arquivos..."
cd $PROJECT_DIR
wget https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/x/bingo_project/app.py -O app.py
cd templates
wget https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/x/bingo_project/templates/admin.html -O admin.html
# Tentativa de baixar outros arquivos HTML (substitua pelos links reais se existirem)
wget https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/x/bingo_project/templates/base.html -O base.html || touch base.html
wget https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/x/bingo_project/templates/register.html -O register.html || touch register.html
wget https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/x/bingo_project/templates/login.html -O login.html || touch login.html
wget https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/x/bingo_project/templates/index.html -O index.html || touch index.html
wget https://raw.githubusercontent.com/sofrenoob/Gggggg/main/s/x/bingo_project/templates/recharge.html -O recharge.html || touch recharge.html
echo "Atenção: Se algum arquivo HTML (base.html, register.html, login.html, index.html, recharge.html) não foi baixado, crie-os manualmente em $PROJECT_DIR/templates/ com o conteúdo correto ou forneça os links reais."

# Criar e ativar ambiente virtual
cd $PROJECT_DIR
echo "Configurando ambiente virtual..."
python -m venv venv
source venv/bin/activate

# Instalar dependências
echo "Instalando dependências Python..."
pip install flask flask-sqlalchemy werkzeug apscheduler mercadopago qrcode pillow

# Configurações adicionais
echo "Edite app.py para inserir seu access token do Mercado Pago e número de WhatsApp."
echo "Exemplo: Substitua 'YOUR_ACCESS_TOKEN' em app.py pelo seu token do Mercado Pago."
echo "Exemplo: Atualize a URL do WhatsApp em app.py (ex: https://wa.me/+5511999999999)."
echo "Para expor o servidor local, instale ngrok com 'pkg install ngrok' e execute 'ngrok http 5000'."

# Executar o app para teste
echo "Executando o app... Acesse http://127.0.0.1:5000 (use ngrok para expor externamente)"
python app.py