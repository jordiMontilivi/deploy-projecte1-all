# Creem la carpeta per al codi compilat de Vue a l'entorn de desenvolupament
sudo mkdir -p /var/www/frontend/dist

# Donem la propietat de la carpeta a l'usuari 'ubuntu' (o l'usuari que faci el desplegament per SSH)
# i al grup 'www-data' (l'usuari d'Apache).
sudo chown -R ubuntu:www-data /var/www/frontend

# Donem permisos de lectura, escriptura i execució al propietari i al grup.
sudo chmod -R 775 /var/www/frontend



# Escoltem el trànsit pel port 80 (HTTP). Més endavant s'hi hauria d'afegir el 443 (HTTPS) amb Let's Encrypt.
<VirtualHost *:80>
    # El domini principal que respondrà a aquest servidor (ex: la-teva-web.cat)
    ServerName elteudomini.com
    
    # La carpeta arrel on Apache anirà a buscar els fitxers físics
    DocumentRoot /var/www/frontend/dist

    # Configuració específica per a aquesta carpeta
    <Directory /var/www/frontend/dist>
        # Desactiva llistar el contingut de la carpeta (seguretat) i permet enllaços simbòlics
        Options -Indexes +FollowSymLinks
        
        # Permet que els fitxers .htaccess sobreescriguin directives (tot i que aquí ho fem directament)
        AllowOverride All
        
        # Dona permís d'accés a tothom a aquesta carpeta (necessari perquè la web sigui pública)
        Require all granted

        # --- INICI DE LA MÀGIA DE VUE ROUTER ---
        # Activem el motor de reescriptura d'URLs d'Apache
        RewriteEngine On
        
        # Establim la ruta base a l'arrel del domini
        RewriteBase /
        
        # Si la petició ja és exactament index.html, no facis res (deixa-la passar) [L = Last rule]
        RewriteRule ^index\.html$ - [L]
        
        # Si el que demana l'usuari (REQUEST_FILENAME) NO és un fitxer real existent (!-f)
        RewriteCond %{REQUEST_FILENAME} !-f
        
        # I si el que demana NO és un directori real existent (!-d)
        RewriteCond %{REQUEST_FILENAME} !-d
        
        # Llavors, agafa qualsevol cosa que hagi demanat (.) i carrega l'index.html
        # Vue rebrà la URL (ex: /usuaris) i mostrarà la pantalla correcta.
        RewriteRule . /index.html [L]
        # --- FI DE LA MÀGIA ---
    </Directory>

    # On es guardaran els registres d'errors d'aquesta web
    ErrorLog ${APACHE_LOG_DIR}/frontend_error.log
    
    # On es guardaran els registres d'accés (qui ens visita i quines pàgines veu)
    CustomLog ${APACHE_LOG_DIR}/frontend_access.log combined
</VirtualHost>