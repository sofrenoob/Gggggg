#!/bin/bash

# Atualiza o sistema
echo "Atualizando o sistema..."
apt update && apt upgrade -y

# Instala o Nginx
echo "Instalando o Nginx..."
apt install -y nginx

# Inicia e habilita o Nginx
systemctl start nginx
systemctl enable nginx

# Instala o MySQL
echo "Instalando o MySQL..."
apt install -y mysql-server

# Configura o MySQL (definir senha root, remover usuários anônimos, etc.)
echo "Configurando o MySQL..."
mysql_secure_installation

# Instala o PHP e extensões comuns
echo "Instalando PHP e extensões..."
apt install -y php-fpm php-mysql php-cli php-curl php-gd php-mbstring php-xml php-zip

# Instala ferramentas adicionais
echo "Instalando Git e Composer..."
apt install -y git
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Configura permissões iniciais para o diretório web
echo "Configurando permissões para /var/www/html..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# Instala o Certbot para SSL (Let's Encrypt)
echo "Instalando Certbot para SSL..."
apt install -y certbot python3-certbot-nginx

# Configura o firewall (UFW)
echo "Configurando o firewall..."
apt install -y ufw
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw enable

# Cria um arquivo de teste PHP
echo "<?php phpinfo(); ?>" > /var/www/html/info.php

# Configura o Nginx para processar PHP
echo "Configurando o Nginx para PHP..."
cat > /etc/nginx/sites-available/default <<EOL
server {
    listen 80;
    server_name _;

    root /var/www/html;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

# Testa a configuração do Nginx
nginx -t

# Reinicia o Nginx
systemctl restart nginx

echo "Configuração concluída! Acesse http://<seu-ip>/info.php para testar o PHP."
echo "Para adicionar SSL, execute: certbot --nginx"