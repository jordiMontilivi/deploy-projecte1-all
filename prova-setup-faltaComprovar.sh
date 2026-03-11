#!/bin/bash

ENVIRONMENT=$1   # dev o prod
ROL=$2           # frontend | backend | all
SERVER_NAME="_"

FRONTEND_DIR=/var/www/frontend
BACKEND_DIR=/var/www/backend

configure_apache_modules() {

    echo "Activant mòduls Apache..."

    sudo a2enmod rewrite

    if [[ "$ENVIRONMENT" == "prod" ]]; then
        sudo a2enmod proxy
        sudo a2enmod proxy_http
    fi

    sudo systemctl restart apache2
}

configure_backend() {

    echo "Configurant Backend Symfony..."

    sudo mkdir -p "$BACKEND_DIR/public"
    sudo mkdir -p "$BACKEND_DIR/var"

    sudo chown -R "$USER":www-data "$BACKEND_DIR"

    BACKEND_PORT=80

    if [[ "$ROL" == "all" || "$ENVIRONMENT" == "dev" ]]; then
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
    AllowOverride All
    Require all granted
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

    sudo chown -R "$USER":www-data "$FRONTEND_DIR"
    sudo chmod -R 775 "$FRONTEND_DIR"

    BACKEND_PROXY=""

    if [[ "$ENVIRONMENT" == "prod" ]]; then

        if [[ -z "$BACKEND_IP" ]]; then
            echo "ERROR: BACKEND_IP no definida"
            exit 1
        fi

        BACKEND_PROXY="
ProxyPreserveHost On
ProxyPass /api http://$BACKEND_IP
ProxyPassReverse /api http://$BACKEND_IP
"
    fi

    echo "Creant VirtualHost Frontend..."

sudo tee /etc/apache2/sites-available/frontend.conf >/dev/null <<EOF
<VirtualHost *:80>

ServerName $SERVER_NAME

DocumentRoot $FRONTEND_DIR

ErrorLog \${APACHE_LOG_DIR}/frontend_error.log
CustomLog \${APACHE_LOG_DIR}/frontend_access.log combined

$BACKEND_PROXY

<Directory $FRONTEND_DIR>

Options -Indexes +FollowSymLinks
AllowOverride All
Require all granted

RewriteEngine On
RewriteBase /

RewriteRule ^index\.html$ - [L]

RewriteCond %{REQUEST_URI} !^/api

RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d

RewriteRule . /index.html [L]

</Directory>

</VirtualHost>
EOF

    sudo a2ensite frontend.conf
}

reload_apache() {

    echo "Recarregant Apache..."
    sudo systemctl reload apache2
}

main() {

    configure_apache_modules

    if [[ "$ROL" == "backend" ]]; then
        configure_backend
    fi

    if [[ "$ROL" == "frontend" ]]; then
        configure_frontend
    fi

    if [[ "$ROL" == "all" ]]; then
        configure_backend
        configure_frontend
    fi

    reload_apache

    echo "Configuració completada"
}

main