#!/bin/bash

# --- VARIABLES ---
SERVER_NAME="localhost" # A PROD hauria de ser el domini real (ex: api.elmeuprojecte.com)
PROJECT_DIR="/var/www/backend"
USER="ubuntu"

echo "--- 1. ACTUALITZANT EL SISTEMA ---"
sudo apt-get update && sudo apt-get upgrade -y

echo "--- 2. INSTAL·LANT APACHE I UTILITATS ---"
# Instal·lem 'acl' per a la gestió professional de permisos (requisit de Symfony)
sudo apt-get install -y apache2 unzip git acl curl

echo "--- 3. INSTAL·LANT PHP 8.3 I EXTENSIONS ---"
sudo apt-get install -y php8.3 libapache2-mod-php8.3 \
    php8.3-mysql php8.3-xml php8.3-mbstring php8.3-curl \
    php8.3-zip php8.3-intl php8.3-gd php8.3-bcmath

echo "--- 4. INSTAL·LANT COMPOSER ---"
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

echo "--- 5. PREPARANT DIRECTORI DEL PROJECTE ---"
sudo mkdir -p $PROJECT_DIR/public

# Creem un fitxer temporal de prova
echo "<?php echo '<h1 style=\"color:green\">SERVIDOR LLEST</h1>'; ?>" | sudo tee $PROJECT_DIR/public/index.php

# Assignem el propietari base
sudo chown -R $USER:www-data $PROJECT_DIR

echo "--- 6. CONFIGURANT APACHE (VIRTUALHOST) ---"
sudo a2enmod rewrite

# Configuració professional per Symfony
sudo bash -c "cat > /etc/apache2/sites-available/symfony.conf <<EOF
<VirtualHost *:80>
    ServerName $SERVER_NAME
    ServerAlias *
    
    DocumentRoot $PROJECT_DIR/public

    # Passar variables d'entorn a Symfony des d'Apache (A PROD posarem 'prod')
    SetEnv APP_ENV dev
    
    # Rutes absolutes i variables d'Apache pels logs
    ErrorLog \${APACHE_LOG_DIR}/backend_error.log
    CustomLog \${APACHE_LOG_DIR}/backend_access.log combined

    <Directory $PROJECT_DIR/public>
        AllowOverride None
        Require all granted
        
        # El Front Controller pattern de Symfony
        FallbackResource /index.php
    </Directory>
</VirtualHost>
EOF"

echo "--- 7. ACTIVANT LLOC I REINICIANT ---"
sudo a2dissite 000-default.conf
sudo a2ensite symfony.conf
sudo systemctl restart apache2

echo "--- 8. APLICANT PERMISOS ACL (Molt important per Symfony) ---"
# Donem permisos d'escriptura a les carpetes de cache i log 
# tant per a l'usuari 'ubuntu' (qui executa les comandes) com 'www-data' (Apache)
sudo mkdir -p $PROJECT_DIR/var
sudo setfacl -R -m u:www-data:rwX -m u:$USER:rwX $PROJECT_DIR/var
sudo setfacl -dR -m u:www-data:rwX -m u:$USER:rwX $PROJECT_DIR/var

echo "--- INSTAL·LACIÓ COMPLETADA ---"