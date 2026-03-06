Aquesta és una situació d'arquitectura molt habitual i excel·lent per ensenyar als alumnes el concepte de **Separació de Responsabilitats (Separation of Concerns)**.

El repte aquí és que en DEV tenim un servidor monolític (tot en un) i en PROD tenim una arquitectura distribuïda (separada).

Per fer-ho de forma professional i "DRY" (no repetir codi), la millor estratègia és crear **un únic script intel·ligent que accepti DOS paràmetres**:

1. **L'entorn:** `dev` o `prod`
2. **El rol del servidor:** `all` (tot junt), `frontend` (només Vue) o `backend` (només Symfony).

> [!NOTE]
> **El problema del Port 80 a DEV:** Si en DEV posem el front i el back a la mateixa màquina, no poden escoltar tots dos pel port 80 amb la mateixa IP. La solució més didàctica sense complicar-los amb dominis DNS és fer que el **Frontend escolti pel port 80** i el **Backend escolti pel port 8000**. Caldrà que obrin el port 8000 al Security Group d'AWS.

### L'Script Definitiu: `setup.sh`

Aquest script aglutina tota la lògica, instal·lant només allò estrictament necessari segons el rol de la màquina.

```bash
#!/bin/bash

# --- 1. VALIDACIÓ DE PARÀMETRES ---
ENTORN=${1:-dev}
ROL=${2:-all} # all, frontend, backend

if [[ ! "$ENTORN" =~ ^(dev|prod)$ ]] || [[ ! "$ROL" =~ ^(all|frontend|backend)$ ]]; then
    echo "❌ Error de sintaxi."
    echo "👉 Ús: sudo bash setup.sh [dev|prod] [all|frontend|backend]"
    echo "Exemples:"
    echo "  sudo bash setup.sh dev all       (Front i Back junts per a proves)"
    echo "  sudo bash setup.sh prod frontend (Només servidor Vue per a Prod)"
    echo "  sudo bash setup.sh prod backend  (Només servidor Symfony per a Prod)"
    exit 1
fi

echo "🚀 Iniciant provisionament. Entorn: [$ENTORN] | Rol: [$ROL]"

# --- VARIABLES GLOBALS ---
BACKEND_DIR="/var/www/backend"
FRONTEND_DIR="/var/www/frontend/dist"
USER="ubuntu"
PHP_INI="/etc/php/8.3/apache2/php.ini"
APACHE_SEC="/etc/apache2/conf-available/security.conf"

echo "--- 2. PAQUETS BASE ---"
sudo apt-get update
# L'Apache i utilitats base fan falta sempre, sigui front o back
sudo apt-get install -y apache2 unzip git acl curl
sudo a2enmod rewrite

# --- 3. LÒGICA DEL BACKEND (SYMFONY) ---
if [ "$ROL" == "all" ] || [ "$ROL" == "backend" ]; then
    echo "⚙️ Configurant requeriments de BACKEND..."

    sudo apt-get install -y php8.3 libapache2-mod-php8.3 \
        php8.3-mysql php8.3-xml php8.3-mbstring php8.3-curl \
        php8.3-zip php8.3-intl php8.3-gd php8.3-bcmath

    curl -sS https://getcomposer.org/installer | php
    sudo mv composer.phar /usr/local/bin/composer

    # Diferències Dev/Prod per a PHP i Apache
    if [ "$ENTORN" == "prod" ]; then
        sudo sed -i 's/display_errors = On/display_errors = Off/g' $PHP_INI
        sudo sed -i 's/;opcache.enable=1/opcache.enable=1/g' $PHP_INI
        sudo sed -i 's/;opcache.validate_timestamps=1/opcache.validate_timestamps=0/g' $PHP_INI
        sudo sed -i 's/ServerTokens OS/ServerTokens Prod/g' $APACHE_SEC
        sudo sed -i 's/ServerSignature On/ServerSignature Off/g' $APACHE_SEC
    else
        sudo sed -i 's/display_errors = Off/display_errors = On/g' $PHP_INI
        sudo sed -i 's/;opcache.validate_timestamps=0/opcache.validate_timestamps=1/g' $PHP_INI
    fi

    # Gestió del port: Si estan junts (all), el back va al 8000. Si estan separats, va al 80.
    BACKEND_PORT=80
    if [ "$ROL" == "all" ]; then
        BACKEND_PORT=8000
        # Afegim el port 8000 a la llista d'escolta d'Apache si no hi és
        grep -q "Listen 8000" /etc/apache2/ports.conf || echo "Listen 8000" | sudo tee -a /etc/apache2/ports.conf
    fi

    sudo mkdir -p $BACKEND_DIR/public $BACKEND_DIR/var
    sudo chown -R $USER:www-data $BACKEND_DIR

    # VirtualHost del Backend
    sudo bash -c "cat > /etc/apache2/sites-available/backend.conf <<EOF
<VirtualHost *:$BACKEND_PORT>
    DocumentRoot $BACKEND_DIR/public
    SetEnv APP_ENV $ENTORN

    ErrorLog \${APACHE_LOG_DIR}/backend_error.log
    CustomLog \${APACHE_LOG_DIR}/backend_access.log combined

    <Directory $BACKEND_DIR/public>
        AllowOverride None
        Require all granted
        FallbackResource /index.php
    </Directory>
</VirtualHost>
EOF"

    sudo a2ensite backend.conf
    sudo setfacl -R -m u:www-data:rwX -m u:$USER:rwX $BACKEND_DIR/var
    sudo setfacl -dR -m u:www-data:rwX -m u:$USER:rwX $BACKEND_DIR/var
fi

# --- 4. LÒGICA DEL FRONTEND (VUE) ---
if [ "$ROL" == "all" ] || [ "$ROL" == "frontend" ]; then
    echo "🎨 Configurant requeriments de FRONTEND..."

    sudo mkdir -p $FRONTEND_DIR
    sudo chown -R $USER:www-data /var/www/frontend
    sudo chmod -R 775 /var/www/frontend

    # VirtualHost del Frontend (Vue Router History Mode)
    sudo bash -c "cat > /etc/apache2/sites-available/frontend.conf <<EOF
<VirtualHost *:80>
    DocumentRoot $FRONTEND_DIR

    ErrorLog \${APACHE_LOG_DIR}/frontend_error.log
    CustomLog \${APACHE_LOG_DIR}/frontend_access.log combined

    <Directory $FRONTEND_DIR>
        Options -Indexes +FollowSymLinks
        AllowOverride All
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

    sudo a2ensite frontend.conf
fi

# --- 5. NETEJA I REINICI ---
echo "🔄 Aplicant canvis a Apache..."
sudo a2dissite 000-default.conf
sudo systemctl restart apache2

echo "✅ INSTAL·LACIÓ COMPLETADA AMB ÈXIT!"
if [ "$ROL" == "all" ]; then
    echo "🌐 Frontend accessible al port 80 (http://IP)"
    echo "🔌 Backend accessible al port 8000 (http://IP:8000) -> Recorda obrir-lo al Security Group d'AWS!"
fi

```

---

### 📘 Com explicar-ho als alumnes (Guia Pedagògica)

1. **Eficiència de Recursos a PROD:** Fixa't que si executem `setup.sh prod frontend`, l'script **no instal·la ni PHP ni Composer**. Per què? Perquè el servidor de frontend només serveix fitxers estàtics (HTML, JS, CSS) compilats. Instal·lar PHP allà seria un risc de seguretat innecessari i consumiria espai de disc.
2. **Evitar col·lisions (El Port 8000):** Dins del bloc del Backend hi ha una petita intel·ligència. Si li diem que el rol és `all`, el backend es configura automàticament al port 8000 perquè el Frontend ocupi el 80. Si els separem a producció, tots dos usaran el 80 a les seves respectives IPs. Això s'anomena **desacoblament**.
3. **El Vue Router (`RewriteRule`):** És important que entenguin que una aplicació Vue només té **un** fitxer (l'`index.html`). Si l'usuari visita `miweb.com/usuaris`, Apache intentarà buscar la carpeta `usuaris/` i donarà un error 404. El bloc `RewriteCond` fa la màgia de dir-li a l'Apache: _"Si el fitxer que et demanen no existeix, retorna-li sempre l'`index.html` i deixa que el Javascript de Vue s'encarregui de canviar la pantalla"_.

Aquesta estructura és exacta a la que utilitzen eines professionals com Ansible o Terraform (on defineixes "rols" per a cada servidor). M'indiques si vols que revisem com quedaran els **Workflows de GitHub Actions** per apuntar als dos servidors en el cas de producció?
