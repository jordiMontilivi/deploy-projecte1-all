#!/bin/bash
# En aquests script vos he posat molts comentaris per a explicar cada pas i que entengueu el que fa cada línia.
# Per al projecte heu d'eliminar els comentaris per a tenir un script més net (però us puc preguntar que fa cada part de l'script i heu de saber-ho, així que millor que entengueu tot el que fa cada línia).
# Per a llançar aquest script, hem de passar-li parametres entorn (dev, prod), i el rol (frontend, backend o all). 
# Si no es passen, per defecte serà dev i all. 
# --- 1. VALIDACIÓ DE PARÀMETRES ---
ENTORN=${1:-dev} # dev o prod
ROL=${2:-all} # all, frontend, backend

# Comprovem que els paràmetres són correctes amb una expressió regular (regex) detectant les paraules clau
if [[ ! "$ENTORN" =~ ^(dev|prod)$ ]] || [[ ! "$ROL" =~ ^(all|frontend|backend)$ ]]; then
    echo " Error de sintaxi."
    echo " Ús: sudo bash full-setup.sh [dev|prod] [all|frontend|backend]"
    echo " Exemples: "
    echo "  sudo bash full-setup.sh dev all       (Front i Back junts per a proves)"
    echo "  sudo bash full-setup.sh prod frontend (Només servidor Vue per a Prod)"
    echo "  sudo bash full-setup.sh prod backend  (Només servidor Symfony per a Prod)"
    exit 1
fi

echo " Iniciant provisionament. Entorn: [$ENTORN] | Rol: [$ROL]"
# Superat aquest punt ja sabem si anem a configurar la instàincia EC2 amb un backend, un frontend o tots dos, 
#   i si serà per a desenvolupament o producció. 
# Això ens permetrà tenir un únic script molt flexible per a totes les situacions. IGUAL ENS ESTEM FLIPANT...
# --- 1. VALIDACIÓ DE PARÀMETRES ---

echo " --- 1.5. COMPROVACIÓ D'IDEMPOTÈNCIA ---"
# Si el fitxer de configuració ja existeix, assumim que la màquina ja està preparada.
# Ho executem des de github actions i comprovarà si la màquina ja està configurada
if [ -f "/etc/apache2/sites-available/backend.conf" ] && [[ "$ROL" =~ ^(all|backend)$ ]]; then
    echo " El servidor BACKEND ja està provisionat. Ixim de l'script sense fer canvis al servidor."
    exit 0
fi

if [ -f "/etc/apache2/sites-available/frontend.conf" ] && [ "$ROL" == "frontend" ]; then
    echo " El servidor FRONTEND ja està provisionat.  Ixim de l'script sense fer canvis al servidor."
    exit 0
fi

# --- VARIABLES GLOBALS ---
SERVER_NAME="localhost" # A Prod hauria de ser el domini real però ara posem localhost perquè estem fent proves amb la IP pública de l'EC2
BACKEND_DIR="/var/www/backend"
FRONTEND_DIR="/var/www/frontend/dist"
USER="ubuntu"
PHP_INI="/etc/php/8.3/apache2/php.ini"
APACHE_SEC="/etc/apache2/conf-available/security.conf"

echo "--- 2. PAQUETS BASE ---"
sudo apt-get update
# L'Apache i utilitats base fan falta sempre, sigui front o back
    #!!! instal·lem apache2, unzip, git, acl i curl
    #!!! activar els mòduls rewrite

# --- 3. LÒGICA DEL BACKEND (SYMFONY) ---
if [ "$ROL" == "all" ] || [ "$ROL" == "backend" ]; then
    echo " Configurant requeriments de BACKEND..."
        #!!!  Instal·lem PHP i extensions necessàries per a Symfony (i la majoria de projectes PHP moderns)
        #!!!  Descarregar i instalar composer globalment (el gestor de dependències de PHP)

    # Diferències Dev/Prod per a PHP i Apache
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

    # IMPORTANT: Gestió del port: Si estan junts (all), el back va al 8000 i el front al 80. Si estan separats, el back va al 80.
    BACKEND_PORT=80
    if [ "$ROL" == "all" ]; then
        #!!! posar el port a 8000 o 8080 com vulguis
        # Afegim el port 8000 a la llista d'escolta d'Apache si no hi és
        grep -q "Listen 8000" /etc/apache2/ports.conf || echo "Listen 8000" | sudo tee -a /etc/apache2/ports.conf
    fi

    #!!! crear els directoris public i var dintre de BACKEND_DIR="/var/www/backend"
    # Assignem el propietari base
    #!!! asignem permisos a ubuntu i www-data al directori backend

    # VirtualHost del Backend
        # El propi script crea el fitxer de configuració del VirtualHost
        # Compte que en alguna de les proves em donava error al utilitzar les variables al fitxer virtualhost, fixeu-vos i en cas que vos passe
        # a vosaltres també canvieu el nom de les variables pel nom complet real del directori (ex: /var/www/backend) 
        # i el nom de l'entorn (dev o prod) directament al fitxer de configuració del VirtualHost, sense utilitzar variables.

    # --- GESTIÓ DE SECRETS I VARIABLES D'ENTORN ---
    # Creem la directiva que anirà dins del VirtualHost depenent de l'entorn
    if [ "$ENTORN" == "prod" ]; then
        echo " Creant fitxer de secrets aïllat per a Producció..."
        
        # 1. Creem el fitxer de secrets separat
        sudo bash -c "cat > /etc/apache2/backend-secrets.conf <<EOF
# --- SECRETS DE PRODUCCIÓ ---
# Omple aquestes variables amb les dades reals de connexió (RDS, etc.) manualment una vegada el servidor estigui provisionat. 
# Aquest fitxer no s'ha de versionar ni compartir, només ha de viure a la instància EC2. 
SetEnv APP_ENV prod
SetEnv APP_SECRET \"CANVIA_AIXO_PEL_TEU_SECRET_DE_PRODUCCIO\"
SetEnv DATABASE_URL \"mysql://admin:contrasenya_real@endpoint-rds:3306/db_produccio\"
EOF"
        
        # 2. Blindem el fitxer perquè només 'root' el pugui llegir (seguretat)
        sudo chown root:root /etc/apache2/backend-secrets.conf
        sudo chmod 600 /etc/apache2/backend-secrets.conf

        # 3. Guardem la instrucció que posarem al VirtualHost
        CONFIG_VARIABLES="Include /etc/apache2/backend-secrets.conf"
    else
        echo " Entorn DEV detectat. S'utilitzarà el fitxer .env.local de la carpeta del projecte."
        # A dev, l'Apache només li diu a PHP quin entorn és. La resta de contrasenyes van al .env.local
        CONFIG_VARIABLES="SetEnv APP_ENV dev"
    fi

    # --- CREACIÓ DEL VIRTUALHOST DEL BACKEND ---
    # El propi script crea el fitxer de configuració del VirtualHost
    sudo bash -c "cat > /etc/apache2/sites-available/backend.conf <<EOF
<VirtualHost *:$BACKEND_PORT>
    #!!! posem el ServerName
    #!!! posem el DocumentRoot amb la carpeta /public

    # Injecció dinàmica de variables (Secrets en PROD o simple APP_ENV en DEV)
    $CONFIG_VARIABLES
    
    # Rutes absolutes i variables d'Apache pels logs
    ErrorLog \${APACHE_LOG_DIR}/backend_error.log
    CustomLog \${APACHE_LOG_DIR}/backend_access.log combined

    <Directory $BACKEND_DIR/public>
        AllowOverride None
        Require all granted
        # El Front Controller pattern de Symfony
        FallbackResource /index.php
    </Directory>
</VirtualHost>
EOF"

    # Activem el VirtualHost del backend
    #!!! activar configuracio backend.conf

    # Donem permisos d'escriptura a les carpetes de cache i log 
    # tant per a l'usuari 'ubuntu' (qui executa les comandes) com 'www-data' (Apache)
    sudo setfacl -R -m u:www-data:rwX -m u:$USER:rwX $BACKEND_DIR/var
    sudo setfacl -dR -m u:www-data:rwX -m u:$USER:rwX $BACKEND_DIR/var
fi

# --- 4. LÒGICA DEL FRONTEND (VUE) ---
if [ "$ROL" == "all" ] || [ "$ROL" == "frontend" ]; then
    echo " Configurant requeriments de FRONTEND..."
    
    # Creem la carpeta per al codi compilat de Vue a l'entorn de desenvolupament
    #!!! crear directori frontend
    # Donem la propietat de la carpeta a l'usuari 'ubuntu' (o l'usuari que faci el desplegament per SSH)
    # i al grup 'www-data' (l'usuari d'Apache).
    #!!! donar permisos a l'usuari i al www-data
    # Donem permisos de lectura, escriptura i execució al propietari i al grup.
    sudo chmod -R 775 /var/www/frontend

    # Escoltem el trànsit pel port 80 (HTTP). Més endavant s'hi hauria d'afegir el 443 (HTTPS) amb Let's Encrypt.
    # VirtualHost del Frontend (Vue Router History Mode)
    sudo bash -c "cat > /etc/apache2/sites-available/frontend.conf <<EOF
<VirtualHost *:80>
    # El domini principal que respondrà a aquest servidor (ex: projecte1.cat) actualment localhost
    ServerName elteudomini.com

    # La carpeta arrel on Apache anirà a buscar els fitxers físics (el codi compilat de Vue)
    DocumentRoot $FRONTEND_DIR

    # On es guardaran els registres d'errors d'aquesta web
    ErrorLog \${APACHE_LOG_DIR}/frontend_error.log

    # On es guardaran els registres d'accés (qui ens visita i quines pàgines veu)
    CustomLog \${APACHE_LOG_DIR}/frontend_access.log combined

    # Configuració específica per a la carpeta /var/www/frontend/dist
    <Directory $FRONTEND_DIR>
        # Desactiva llistar el contingut de la carpeta (seguretat) i permet enllaços simbòlics
        Options -Indexes +FollowSymLinks

        # Permet que els fitxers .htaccess sobreescriguin directives (tot i que aquí ho fem directament)
        AllowOverride All

        # Dona permís d'accés a tothom a aquesta carpeta (necessari perquè la web sigui pública)
        Require all granted

        # Configuració per a Single Page Applications (Vue/React/Angular)
        RewriteEngine On
        RewriteBase /
        RewriteRule ^index\.html$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.html [L]
    </Directory>
</VirtualHost>
EOF"

    #!!! activem el modul de frontend
fi

# --- 5. NETEJA I REINICI ---
echo " Aplicant canvis a Apache..."
#!!! treiem els permisos a default
#!!! restart apache2

echo " INSTAL·LACIÓ COMPLETADA AMB ÈXIT!"
if [ "$ROL" == "all" ]; then
    echo " Frontend accessible al port 80 (http://IP)"
    echo " Backend accessible al port 8000 (http://IP:8000) -> Recorda obrir-lo al Security Group d'AWS!"
fi