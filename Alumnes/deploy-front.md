##FrontEnd VueJS
###Guia Resum: Desplegament de Vue.js a Dev i Prod

**1. Preparar els Servidors EC2 (A fer tant a Dev com a Prod)**  

* **RECORDA:** El servidor FrontEnd de Dev i el de Prod són màquines diferents. Cada un té la seva pròpia IP, configuració i secrets.  
  * Si despleguem en **DEV** compartim aquesta instància amb el backEnd i tindrem carpetes diferents per al front i el back (`/var/www/frontend` i `/var/www/backend`).
  * Si despleguem en **PROD** tenim una instància dedicada només al FrontEnd, i el directori serà `/var/www/frontend` (sense necessitat de diferenciar entre front i back perquè el back està en una màquina diferent).
  * **tenim un  full-setup.sh** que ja automatitza tota la configuració bàsica del servidor (instal·la Apache, PHP, Composer, etc.) i també aplica les diferències entre Dev i Prod. Només cal executar-lo amb el paràmetre corresponent (`sudo bash full-setup.sh dev all` o `sudo bash full-setup.sh prod frontend`)... però aquí us deixe el pas a pas manual per entendre millor què fa l'script i com configurar-ho tot des de zero atenent a les necessitats del frontend.  
* **Crear la carpeta destí:** Crear el directori on viurà el projecte compilat (`sudo mkdir -p /var/www/frontend/dist`).
* **Assignar permisos:** Donar propietat a l'usuari que fa el desplegament i a Apache (`sudo chown -R ubuntu:www-data /var/www/frontend`), i aplicar els permisos adequats (`sudo chmod -R 775 /var/www/frontend`).
* **Activar mòduls:** Habilitar el mòdul de reescriptura d'Apache (`sudo a2enmod rewrite`).

**2. Configurar Apache (A fer tant a Dev com a Prod)**

* **Crear el VirtualHost:** Crear un fitxer `.conf` a `/etc/apache2/sites-available/` apuntant al `DocumentRoot` `/var/www/frontend/dist`.
* **Regles de Vue Router:** Afegir el bloc `<Directory>` amb el `RewriteEngine On` perquè qualsevol ruta que no sigui un fitxer físic redirigeixi a `index.html`. Això evita l'error 404 en recarregar la pàgina.
* **Activar la web:** Habilitar el lloc web (`sudo a2ensite nom-del-fitxer.conf`) i reiniciar Apache (`sudo systemctl restart apache2`).

**3. Configurar els Secrets a GitHub**

* **Anar a la configuració:** Al repositori, anar a *Settings > Secrets and variables > Actions*.
* **Crear les credencials de Prod:** Afegir `PROD_SERVER_HOST` (IP), `PROD_SERVER_USER` (ex: ubuntu) i `PROD_SERVER_SSH_KEY` (clau `.pem`).
* **Crear les credencials de Dev:** Afegir exactament el mateix però amb el prefix DEV (`DEV_SERVER_HOST`, `DEV_SERVER_USER`, `DEV_SERVER_SSH_KEY`).

**4. Crear el Workflow de GitHub Actions (CI/CD)**

* **Crear el fitxer YAML:** Crear el fitxer `.github/workflows/deploy.yml` dins del projecte Vue.
* **Definir els disparadors (Triggers):** Configurar l'acció `on: push` per a les branques `main` i `develop`.
* **Configurar els passos de compilació:** Afegir els passos per fer el Checkout del codi, configurar Node.js, instal·lar dependències (`npm ci`) i compilar l'app (`npm run build`).
* **Configurar l'enviament (SCP):** Utilitzar el paquet `scp-action` enviant la carpeta `dist/*` a la ruta unificada `/var/www/frontend/dist`.
* **Aplicar els condicionals:** Utilitzar la sintaxi `condició && cert || fals` a les variables d'host, user i key per triar automàticament el secret de Prod o Dev segons la branca que executi l'acció.

**5. (NO DER DE MOMENT) Configurar el Backend Symfony**

* **CORS:** Instal·lar el `NelmioCorsBundle` al servidor backend.
* **Donar permisos:** Configurar l'arxiu `nelmio_cors.yaml` per permetre que els dominis de Vue (tant el de Dev com el de Prod) puguin fer peticions a l'API de Symfony sense ser bloquejats pel navegador.