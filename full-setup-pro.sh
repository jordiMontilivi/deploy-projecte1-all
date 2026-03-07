#!/bin/bash

# ==========================================================
# FULL SERVER SETUP SCRIPT
# Provisiona una instància EC2 per executar:
#   - Backend Symfony
#   - Frontend Vue
#
# Ús:
#   sudo bash full-setup.sh [dev|prod] [all|frontend|backend]
#
# Exemple:
#   sudo bash full-setup.sh dev all
# ==========================================================

set -euo pipefail

# ----------------------------------------------------------
# 1. PARÀMETRES
# ----------------------------------------------------------

ENTORN=${1:-dev}
ROL=${2:-all}

if [[ ! "$ENTORN" =~ ^(dev|prod)$ ]] || [[ ! "$ROL" =~ ^(all|frontend|backend)$ ]]; then
    echo "Error de sintaxi."
    echo "Ús: sudo bash full-setup.sh [dev|prod] [all|frontend|backend]"
    exit 1
fi

echo "Provisionant servidor..."
echo "Entorn: $ENTORN"
echo "Rol: $ROL"

# ----------------------------------------------------------
# VARIABLES GLOBALS
# ----------------------------------------------------------

USER="ubuntu"

SERVER_NAME="localhost"

BACKEND_DIR="/var/www/backend"
FRONTEND_DIR="/var/www/frontend/dist"

PHP_INI="/etc/php/8.3/apache2/php.ini"
APACHE_SEC="/etc/apache2/conf-available/security.conf"

# ----------------------------------------------------------
# FUNCIONS
# ----------------------------------------------------------

install_base_packages() {

    echo "Instal·lant paquets base..."

    sudo apt-get update

    sudo apt-get install -y \
        apache2 \
        git \
        unzip \
        curl \
        acl

    sudo a2enmod rewrite

}

install_php() {

    echo "Instal·lant PHP i extensions..."

    sudo apt-get install -y \
        php8.3 \
        libapache2-mod-php8.3 \
        php8.3-mysql \
        php8.3-xml \
        php8.3-mbstring \
        php8.3-curl \
        php8.3-zip \
        php8.3-intl \
        php8.3-gd \
        php8.3-bcmath

}

install_composer() {

    if command -v composer >/dev/null 2>&1; then
        echo "Composer ja està instal·lat"
        return
    fi

    echo "Instal·lant Composer..."

    curl -sS https://getcomposer.org/installer | php

    sudo mv composer.phar /usr/local/bin/composer

}

configure_php_dev() {

    echo "Configurant PHP per a desenvolupament..."

    sudo sed -i 's/display_errors = Off/display_errors = On/g' "$PHP_INI"

}

configure_php_prod() {

    echo "Configurant PHP per producció..."

    sudo sed -i 's/display_errors = On/display_errors = Off/g' "$PHP_INI"

    sudo sed -i 's/;opcache.enable=1/opcache.enable=1/g' "$PHP_INI"

    sudo sed -i 's/;opcache.validate_timestamps=1/opcache.validate_timestamps=0/g' "$PHP_INI"

    sudo sed -i 's/ServerTokens OS/ServerTokens Prod/g' "$APACHE_SEC"

    sudo sed -i 's/ServerSignature On/ServerSignature Off/g' "$APACHE_SEC"

}

configure_backend() {

    echo "Configurant Backend Symfony..."

    sudo mkdir -p "$BACKEND_DIR/public"
    sudo mkdir -p "$BACKEND_DIR/var"

    sudo chown -R "$USER":www-data "$BACKEND_DIR"

    BACKEND_PORT=80

    if [[ "$ROL" == "all" ]]; then
        BACKEND_PORT=8000

        if ! grep -q "Listen 8000" /etc/apache2/ports.conf; then
            echo "Listen 8000" | sudo tee -a /etc/apache2/ports.conf
        fi
    fi

    echo "Creant VirtualHost Backend..."

sudo tee /etc/apache2/sites-available/backend.conf >/dev/null <<EOF
<VirtualHost *:$BACKEND_PORT>

ServerName $SERVER_NAME
DocumentRoot $BACKEND_DIR/public

ErrorLog \${APACHE_LOG_DIR}/backend_error.log
CustomLog \${APACHE_LOG_DIR}/backend_access.log combined

<Directory $BACKEND_DIR/public>
    AllowOverride None
    Require all granted
    FallbackResource /index.php
</Directory>

</VirtualHost>
EOF

    sudo a2ensite backend.conf

    sudo setfacl -R -m u:www-data:rwX -m u:$USER:rwX "$BACKEND_DIR/var"
    sudo setfacl -dR -m u:www-data:rwX -m u:$USER:rwX "$BACKEND_DIR/var"

}

configure_frontend() {

    echo "Configurant Frontend Vue..."

    sudo mkdir -p "$FRONTEND_DIR"

    sudo chown -R "$USER":www-data /var/www/frontend

    sudo chmod -R 775 /var/www/frontend

    echo "Creant VirtualHost Frontend..."

sudo tee /etc/apache2/sites-available/frontend.conf >/dev/null <<EOF
<VirtualHost *:80>

ServerName $SERVER_NAME

DocumentRoot $FRONTEND_DIR

ErrorLog \${APACHE_LOG_DIR}/frontend_error.log
CustomLog \${APACHE_LOG_DIR}/frontend_access.log combined

<Directory $FRONTEND_DIR>

Options -Indexes +FollowSymLinks
AllowOverride All
Require all granted

RewriteEngine On
RewriteBase /

RewriteRule ^index\.html$ - [L]

RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d

RewriteRule . /index.html [L]

</Directory>

</VirtualHost>
EOF

    sudo a2ensite frontend.conf

}

restart_apache() {

    echo "Reiniciant Apache..."

    sudo a2dissite 000-default.conf || true

    sudo systemctl restart apache2

}

# ----------------------------------------------------------
# EXECUCIÓ
# ----------------------------------------------------------

install_base_packages

if [[ "$ROL" == "backend" || "$ROL" == "all" ]]; then

    install_php

    install_composer

    if [[ "$ENTORN" == "prod" ]]; then
        configure_php_prod
    else
        configure_php_dev
    fi

    configure_backend

fi

if [[ "$ROL" == "frontend" || "$ROL" == "all" ]]; then

    configure_frontend

fi

restart_apache

echo "-------------------------------------"
echo "Provisionament completat correctament"
echo "-------------------------------------"

if [[ "$ROL" == "all" ]]; then
    echo "Frontend → http://IP"
    echo "Backend → http://IP:8000"
fi