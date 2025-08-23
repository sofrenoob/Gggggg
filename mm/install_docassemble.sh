

# Script de instalação do Docassemble com configurações interativas

echo "Iniciando instalação do Docassemble em Ubuntu"

# Verifica se está como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute como root ou usando sudo"
  exit 1
fi

# Atualiza o sistema
apt update && apt upgrade -y

# Instala Docker e Docker Compose
apt install -y docker.io docker-compose git

# Habilita Docker
systemctl enable --now docker

# Pergunta o domínio
read -p "Digite o seu domínio (ex: seudominio.com): " DOMAIN

# Pergunta o email para SSL
read -p "Digite o seu email para certificados SSL (Let's Encrypt): " EMAIL

# Clona o repositório do Docassemble
git clone https://github.com/jhpyle/docassemble.git /opt/docassemble

cd /opt/docassemble

# Cria arquivo de override para configuração do domínio
cat > docker-compose.override.yml <<EOF
version: '3.8'

services:
  web:
    environment:
      DA_DOMAIN: '${DOMAIN}'
      DA_EMAIL: '${EMAIL}'
EOF

# Inicia o Docker
docker-compose up -d

echo "Sistema iniciado. Aguardando alguns minutos para o serviço ficar acessível..."

# Aguarda um pouco para o sistema iniciar
sleep 60

# Configuração do Nginx como proxy reverso
echo "Configurando Nginx como proxy reverso..."

# Instala Nginx e Certbot
apt install -y nginx certbot python3-certbot-nginx

# Cria arquivo de configuração do Nginx
cat > /etc/nginx/sites-available/docassemble <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Ativa a configuração
ln -s /etc/nginx/sites-available/docassemble /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Solicita certificado SSL
echo "Solicitando certificado SSL via Certbot..."

certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos -m ${EMAIL}

# Reinicia Nginx para aplicar SSL
systemctl restart nginx

echo "Instalação concluída!"
echo "Acesse https://${DOMAIN} para usar o Docassemble."
