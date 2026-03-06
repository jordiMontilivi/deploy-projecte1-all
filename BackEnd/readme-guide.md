# Guia Ràpida: Desplegament del Backend (Symfony a AWS EC2)

Aquesta guia resumeix els passos essencials per desplegar el nostre backend de forma segura, automatitzada (mitjançant GitHub Actions) i aplicant bones pràctiques d'administració de sistemes.

## FASE 1: Preparació del Servidor (AWS EC2)

_Aquest pas només s'ha de fer UNA VEGADA a la vida del servidor._
_Aquests passos ja estan automatitzats al nostre script de setup (`full-setup.sh`), però aquí us deixe el pas a pas manual per entendre-ho millor._

1. Connecta't a la teva màquina d'AWS per SSH:
   `ssh -i la_teva_clau.pem ubuntu@IP_DEL_TEU_SERVIDOR`

2. Copia el fitxer `full-setup.sh` al servidor (pots fer-ho amb SFTP o amb `scp`):
   `scp -i la_teva_clau.pem full-setup.sh ubuntu@IP_DEL_TEU_SERVIDOR:/home/ubuntu/`

   > **Alternativa:** Si no vols copiar l'script, pots crear-lo directament al servidor amb `nano full-setup.sh` i enganxar-hi el contingut manualment. Aquesta és una opció més lenta i propensa a errors, però pot servir si tens problemes amb la transferència de fitxers.
   > `nano full-setup.sh` _(enganxa-hi el codi i desa)_

3. Executa l'script indicant que vols preparar, un prod/dev backend/frontend/al
   `sudo bash full-setup.sh prod backend`

4. Comprova que l'Apache està corrent sense errors:
   `sudo systemctl status apache2`

5. Esborra l'script de la màquina per seguretat:
   `rm -f full-setup.sh`

## FASE 2: Determina com has de configurar les variables sensibles segons dev o prod. Tens un readme-env.md que ho explica detalladament

_Aquesta fase connecta el teu ordinador local amb el servidor per protegir les contrasenyes._

1. **A DEV:**
   1. crea i gestiona el fitxer de configuració **.env.local** amb la informació necessaria al servidor backend

2. **A PROD:**
   a. Fitxer secrets i jugar amb permisos
   1. Crear un fitxer de secrets al backend `backend-secrets.conf` que configurarem amb claus sensibles i li treurem els permisos a ubuntu i a www.data per a que només Apache amb root pugui utilitzar-lo.
   2. Afegeix les variables sensibles a aquest fitxer de configuració.

   b. Secrets de symfony
   1. **A l'ORDINADOR LOCAL:** Genera les claus criptogràfiques de producció al symfony local:
      `php bin/console secrets:generate-keys --env=prod`
   2. **A l'ORDINADOR LOCAL:** Afegeix els teus secrets (ex: la connexió a la base de dades):
      `php bin/console secrets:set DATABASE_URL --env=prod`
   3. **A l'ORDINADOR LOCAL:** Copiem el contingut del fitxer `config/secrets/prod/prod.decrypt.private.php` al servidor EC2 `/var/www/backend/config/secrets/prod/prod.decrypt.private.php`

## FASE 3: Configuració de GitHub Actions

_Preparem el repositori perquè pugui parlar amb el nostre servidor AWS._

1. Ves al teu repositori de GitHub > **Settings** > **Secrets and variables** > **Actions**.
2. Afegeix els següents _Repository secrets_:
   - `TARGET_HOST`: La IP pública o domini del teu servidor EC2.
   - `TARGET_USER`: L'usuari del servidor (habitualment `ubuntu`).
   - `TARGET_KEY`: El contingut sencer del teu fitxer `.pem` (la clau privada per entrar per SSH).
3. Assegura't que el teu fitxer de workflow `.github/workflows/deploy-backend-prod.yml` té la línia d'exclusió a l'rsync per no esborrar la clau privada del servidor:
   `--exclude 'config/secrets/prod/prod.decrypt.private.php'`

## FASE 4: El Desplegament

_A partir d'ara, aquest és l'únic pas que hauràs de repetir cada cop que facis canvis al codi._

1. **A l'ORDINADOR LOCAL:** Afegeix els canvis a Git (recorda que la clau privada no es pujarà perquè està al `.gitignore`):
   `git add .`
2. **A l'ORDINADOR LOCAL:** Fes el commit:
   `git commit -m "Preparant llançament a Producció"`
3. **A l'ORDINADOR LOCAL:** Envia el codi a la branca main, develop, ...:
   `git push origin main`
4. **A GITHUB:** Ves a la pestanya **Actions** i disfruta de l'espectacle del desplegament totalment automatitzat.
   - Veuràs com els servidors de GitHub (runner ubuntu) descarreguen el teu codi, i fa un desplegament per artifacts -> instal·len el PHP (`setup-php`), descarreguen la carpeta `vendor/` amb Composer, envien el paquet per `rsync` a l'EC2 i finalment executen les migracions i netegen la memòria cau en prod. o bé
   - Veuràs com els servidors de GitHub (runner ubuntu) descarreguen el teu codi, i envien el paquet per `rsync` a l'EC2 excloent algunes carpetes com la carpeta `vendor/` ja que executarà el composer en el propi servidor, ... i netegen la memòria cau en dev

**Comprova que el teu backend ja és a Producció.**
