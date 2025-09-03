#!/bin/bash

set -e

echo "==== Atualizando sistema ===="
sudo apt update && sudo apt upgrade -y
sudo apt install -y software-properties-common

echo "==== Instalando PHP e extensões ===="
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install -y php8.1 php8.1-cli php8.1-fpm php8.1-xml php8.1-mbstring php8.1-curl php8.1-zip php8.1-mysql php8.1-gd php8.1-bcmath php8.1-intl php8.1-pgsql unzip

echo "==== Instalando Composer ===="
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

echo "==== Instalando Node.js e npm ===="
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

echo "==== Instalando MySQL ===="
sudo apt install -y mysql-server
sudo mysql_secure_installation

echo "==== Instalando Nginx ===="
sudo apt install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx

echo "==== Clonando o repositório ===="
cd /var/www/
sudo git clone https://github.com/alfalemos-cyber/viper-cassino.git
sudo chown -R $USER:$USER viper-cassino
cd viper-cassino

echo "==== Instalando dependências PHP ===="
composer install --no-interaction --prefer-dist --optimize-autoloader

echo "==== Instalando dependências Node.js ===="
npm install

echo "==== Configurando ambiente ===="
cp .env.example .env
echo "Edite o arquivo .env com suas configurações de banco e email antes de prosseguir!"
echo "Pressione ENTER para continuar após editar o .env..."
read

echo "==== Gerando chave do app ===="
php artisan key:generate

echo "==== Rodando migrações ===="
php artisan migrate --seed

echo "==== Compilando assets ===="
npm run build

echo "==== Ajustando permissões ===="
sudo chown -R www-data:www-data storage bootstrap/cache
sudo chmod -R 775 storage/bootstrap/cache
sudo chown -R www-data:www-data public

echo "==== Criando configuração do Nginx ===="
sudo tee /etc/nginx/sites-available/viper-cassino.conf > /dev/null <<'EOF'
server {
    listen 80;
    server_name cassino.alfalemos.shop 185.194.205.50;
    root /var/www/viper-cassino/public;

    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/viper-cassino.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

echo "==== Instalação finalizada! Acesse http://cassino.alfalemos.shop para abrir o Viper Cassino ===="
echo "Para HTTPS, execute: sudo apt install -y certbot python3-certbot-nginx && sudo certbot --nginx -d cassino.alfalemos.shop"