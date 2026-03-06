#!/bin/bash

# --- 1. VALIDACIÓ DE L'ENTORN ---
# Agafem el primer paràmetre que es passa a l'script. Si està buit, per defecte serà 'dev'.
ENTORN=${1:-dev} 

# Comprovem que l'alumne ha posat 'dev' o 'prod'
if [ "$ENTORN" != "dev" ] && [ "$ENTORN" != "prod" ]; then
    echo " Error: L'entorn ha de ser 'dev' o 'prod'."
    echo " Ús correcte: sudo bash setup.sh dev  O  sudo bash setup.sh prod"
    exit 1
fi

echo " Iniciant configuració del servidor per a l'entorn: [ $ENTORN ]"

# --- VARIABLES ---
SERVER_NAME="localhost" # A Prod hauria de ser el domini real
PROJECT_DIR="/var/www/backend"
USER="ubuntu"
PHP_INI="/etc/php/8.3/apache2/php.ini"
APACHE_SEC="/etc/apache2/conf-available/security.conf"

echo "--- 2. ACTUALITZANT I INSTAL·LANT PAQUETS ---"
sudo apt-get update
sudo apt-get install -y apache2 unzip git acl curl
sudo apt-get install -y php8.3 libapache2-mod-php8.3 \
    php8.3-mysql php8.3-xml php8.3-mbstring php8.3-curl \
    php8.3-zip php8.3-intl php8.3-gd php8.3-bcmath

curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

echo "--- 3. APLICANT DIFERÈNCIES DEV / PROD ---"
# Aquí utilitzem 'sed' per buscar i reemplaçar línies als fitxers de configuració

if [ "$ENTORN" == "prod" ]; then
    echo " Aplicant configuracions de PRODUCCIÓ (Seguretat i Rendiment)..."
    
    # PHP: Ocultar errors perquè no els vegin els usuaris
    sudo sed -i 's/display_errors = On/display_errors = Off/g' $PHP_INI
    
    # PHP: Activar i optimitzar OPcache (no comprova si els fitxers canvien = màxim rendiment)
    sudo sed -i 's/;opcache.enable=1/opcache.enable=1/g' $PHP_INI
    sudo sed -i 's/;opcache.validate_timestamps=1/opcache.validate_timestamps=0/g' $PHP_INI
    
    # APACHE: Amagar informació del servidor a les capçaleres HTTP (Seguretat)
    sudo sed -i 's/ServerTokens OS/ServerTokens Prod/g' $APACHE_SEC
    sudo sed -i 's/ServerSignature On/ServerSignature Off/g' $APACHE_SEC

else
    echo " Aplicant configuracions de DEVELOP (Depuració)..."
    
    # PHP: Mostrar errors per facilitar la feina als programadors
    sudo sed -i 's/display_errors = Off/display_errors = On/g' $PHP_INI
    
    # PHP: Assegurar que OPcache comprova els canvis a l'instant (perquè el dev vegi el seu codi)
    sudo sed -i 's/;opcache.validate_timestamps=0/opcache.validate_timestamps=1/g' $PHP_INI
fi

echo "--- 4. CONFIGURANT APACHE (VIRTUALHOST) ---"
sudo mkdir -p $PROJECT_DIR/public
# Assignem el propietari base
sudo chown -R $USER:www-data $PROJECT_DIR

sudo a2enmod rewrite

# Creem el VirtualHost injectant la variable $ENTORN directament
sudo bash -c "cat > /etc/apache2/sites-available/symfony.conf <<EOF
<VirtualHost *:80>
    ServerName $SERVER_NAME
    DocumentRoot $PROJECT_DIR/public

    # Variable dinàmica! Apache dirà a Symfony si és dev o prod
    SetEnv APP_ENV $ENTORN
    
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

echo "--- 5. ACTIVANT CONFIGURACIONS I PERMISOS ---"
sudo a2dissite 000-default.conf
sudo a2ensite symfony.conf
sudo systemctl restart apache2

# Donem permisos d'escriptura a les carpetes de cache i log 
# tant per a l'usuari 'ubuntu' (qui executa les comandes) com 'www-data' (Apache)
sudo mkdir -p $PROJECT_DIR/var
sudo setfacl -R -m u:www-data:rwX -m u:$USER:rwX $PROJECT_DIR/var
sudo setfacl -dR -m u:www-data:rwX -m u:$USER:rwX $PROJECT_DIR/var

echo " INSTAL·LACIÓ COMPLETADA PER A L'ENTORN: $ENTORN"