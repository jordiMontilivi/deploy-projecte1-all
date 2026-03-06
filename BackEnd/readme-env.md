# Gestió de Dades Sensibles i Variables d'Entorn (DEV vs PROD)

Un dels principis fonamentals de la seguretat informàtica i la metodologia _Twelve-Factor App_ és que **les credencials (contrasenyes de bases de dades, claus d'API, secrets de l'aplicació) MAI s'han de guardar al repositori de codi (Git)**.

Si pugem el fitxer `.env` amb contrasenyes reals a GitHub, qualsevol amb accés al repositori podria comprometre el nostre servidor. Per això, utilitzem estratègies diferents depenent de si estem a l'entorn de Desenvolupament (DEV) o de Producció (PROD).

---

## ESTRATÈGIA 1: L'Entorn de DEV (El fitxer `.env.local`)

Les variables .env.local no s'haurien de pujar al repositori perquè contenen dades sensibles. El nostre Symfony ja hauria de tenir un .gitignore per a no pujar-les al servidor, igualment el nostre workflow de GitHub Actions estan configurats per **ignorar aquest fitxer** i permetre que cada desenvolupador tingui la seva pròpia còpia local amb les seves credencials.
A l'entorn de desenvolupament, utilitzarem un fitxer local que **Git ignora automàticament**. El nostre workflow de GitHub Actions ja està configurat per **no sobreescriure ni esborrar** aquest fitxer gràcies a la regla `--exclude '.env.local'` de la comanda `rsync`.

### Pas a pas per a DEV:

1. Connecta't per SSH a la teva màquina EC2 de DEV:

```bash
  ssh ubuntu@<IP_MÀQUINA_DEV>
```

2. Ves a la carpeta arrel del backend:

```bash
  cd /var/www/backend
```

3. Crea una còpia del fitxer d'exemple i anomena'l `.env.local`:

```bash
  cp .env .env.local
```

4. Edita el fitxer i posa-hi les credencials reals de la teva base de dades local:

```bash
  nano .env.local
```

_Exemple de contingut:_

```env
  APP_ENV=dev
  APP_SECRET=aqui_un_secret_aleatori_generat
  DATABASE_URL="mysql://usuari:contrasenya@127.0.0.1:3306/nom_base_dades?serverVersion=8.0"

```

5. Desa el fitxer (`Ctrl+O`, `Enter`, `Ctrl+X`). A partir d'ara, Symfony prioritzarà aquest fitxer sempre.

---

## ESTRATÈGIA 2: L'Entorn de PROD (Variables d'Apache)

### Opcio A.

En comptes d'escriure les variables al backend.conf, crearem un fitxer de secrets separat que només l'usuari root podrà llegir, i el connectarem a Apache. **Tots aquests passos ja estan automatitzats al nostre script de setup** (`full-setup.sh`), però aquí us deixe el pas a pas manual per entendre-ho millor. Homés heu de **modificar el punt 2 de forma manual** ja que l'script tindrà dades genèriques que haureu de canviar pel vostre cas concret (contrasenya real, endpoint de RDS, etc.) i executar el pas 5 per a que Apache carregue els secrets.

Pas a pas definitiu per a PROD:

1. Crear el fitxer de secrets aïllat o utilitzar el que ja hem creat al full-setup.sh
   Ens connectem a l'EC2 de producció i creem un arxiu nou fora de l'abast de qualsevol usuari estàndard.

```bash
  sudo nano /etc/apache2/backend-secrets.conf
```

2. Definir-hi les variables (SetEnv)
   A dins d'aquest fitxer, només hi posem les variables sensibles, res de configuració d'Apache:

```bash
  SetEnv APP_ENV prod
  SetEnv APP_SECRET "el_teu_secret_super_segur_de_produccio"
  SetEnv DATABASE_URL "mysql://admin:ContrasenyaRDS!@endpoint-del-rds.amazonaws.com:3306/db_produccio"
```

Desem i tanquem (Ctrl+O, Enter, Ctrl+X).

3. Blindar el fitxer (El toc de seguretat)
   Això és clau per als alumnes: canviem els permisos perquè només l'arrel (root) pugui llegir i modificar aquest fitxer. Ni l'usuari ubuntu ni l'usuari web (www-data) el podran obrir directament amb un cat.

```bash
  sudo chown root:root /etc/apache2/backend-secrets.conf
  sudo chmod 600 /etc/apache2/backend-secrets.conf
```

4. Connectar els secrets al VirtualHost
   Ara editem el VirtualHost principal:

```bash
  sudo nano /etc/apache2/sites-available/backend.conf
```

I a dins, simplement fem un Include del fitxer de secrets:

```apache
  <VirtualHost *:80>
      DocumentRoot /var/www/backend/public

      # Carreguem els secrets de forma segura des d'un fitxer extern
      Include /etc/apache2/backend-secrets.conf

      ErrorLog ${APACHE_LOG_DIR}/backend_error.log
      CustomLog ${APACHE_LOG_DIR}/backend_access.log combined

      <Directory /var/www/backend/public>
          AllowOverride None
          Require all granted
          FallbackResource /index.php
      </Directory>
  </VirtualHost>
```

5. Comprovar i reiniciar
   Com sempre que toquem l'Apache, validem que la sintaxi sigui correcta i reiniciem:

```bash
  sudo apache2ctl configtest
  sudo systemctl restart apache2
```

### Opció B. (symfony secrets)

En comptes de crear un fitxer de secrets separat, podem utilitzar el sistema de xifrat natiu de Symfony. Això és més segur perquè les credencials no es guarden en text pla a cap lloc, però requereix una mica més de configuració inicial (especialment per a la clau privada que desxifra els secrets a producció).

Anem a desglossar-ho pas a pas, des de l'ordinador del desenvolupador fins a la modificació del nostre script de provisionament `full-setup.sh`.

---

### Fase 1: El Desenvolupador (A l'ordinador local)

Abans de tocar el servidor, heu de preparar symfony amb la clau publica i la clau privada a l'ordinador:

1. Executa `php bin/console secrets:generate-keys --env=prod`. Això crea la clau pública i la privada a `config/secrets/prod/`.
2. Guarda els secrets de producció (ex: `php bin/console secrets:set DATABASE_URL --env=prod`). Afegeix tots els secrets necessaris (BD, APIs, etc.). Aquestes dades es xifren automàticament i es guarden a `config/secrets/prod/`.
3. Al guardar els canvis i pujar a git (`git add .` i un `git commit`). Git pujarà la clau pública i els secrets encriptats, però ignorarà automàticament la clau privada (gràcies al `.gitignore` de Symfony).
4. **Copia el contingut del fitxer `config/secrets/prod/prod.decrypt.private.php`** (el necessitarem d'espés d'executar el full-setup.sh al servidor).

### Fase 2: Modificació de l'script `full-setup.sh`

Ara hem d'adaptar el nostre script. Com que la `DATABASE_URL` i la resta de claus sensibles ja viatgen encriptades dins del codi, l'Apache del servidor de Producció ja no l'ha de saber. L'únic que mantindrem a l'Apache és l'`APP_SECRET` i l'`APP_ENV`.

Substitueix el bloc sencer de **GESTIÓ DE SECRETS I VARIABLES D'ENTORN** del teu script per aquest:

```bash
    # --- GESTIÓ DE SECRETS I VARIABLES D'ENTORN (VIA SYMFONY SECRETS) ---
    if [ "$ENTORN" == "prod" ]; then
        echo " Creant fitxer de variables bàsiques per a Producció..."

        # 1. Creem el fitxer (Ja NO posem la DATABASE_URL aquí)
        sudo bash -c "cat > /etc/apache2/backend-secrets.conf <<EOF
# --- VARIABLES BASE DE PRODUCCIÓ ---
# Els secrets reals (BD, APIs) estan encriptats al repositori (Symfony Secrets)
SetEnv APP_ENV prod
SetEnv APP_SECRET \"CANVIA_AIXO_PEL_TEU_SECRET_DE_PRODUCCIO_32_CHARS\"
EOF"

        # 2. Blindem el fitxer
        sudo chown root:root /etc/apache2/backend-secrets.conf
        sudo chmod 600 /etc/apache2/backend-secrets.conf

        # 3. Guardem la instrucció pel VirtualHost
        CONFIG_VARIABLES="Include /etc/apache2/backend-secrets.conf"

        # 4. PREPAREM LA CARPETA PER A LA CLAU PRIVADA
        # Creem el directori on posarem manualment la clau privada abans que es faci el primer desplegament
        sudo mkdir -p $BACKEND_DIR/config/secrets/prod
        sudo chown -R $USER:www-data $BACKEND_DIR/config
        sudo chmod -R 775 $BACKEND_DIR/config

        echo " ATENCIÓ: Recorda pujar el fitxer 'prod.decrypt.private.php' a $BACKEND_DIR/config/secrets/prod/"
    else
        echo " Entorn DEV detectat. S'utilitzarà el fitxer .env.local de la carpeta del projecte."
        CONFIG_VARIABLES="SetEnv APP_ENV dev"
    fi

```

### Fase 3: L'Administrador de Sistemes (A l'EC2 de Producció)

Un cop heu executat el `full-setup.sh` a l'EC2 i s'ha configurat l'Apache, ha de col·locar la clau privada físicament al servidor **una única vegada**.

1. Es connecta per SSH a l'EC2.
2. Crea l'arxiu de la clau privada:

```bash
  nano /var/www/backend/config/secrets/prod/prod.decrypt.private.php
```

3. Enganxa el contingut que havia copiat al seu ordinador a la Fase 1, desa i tanca (`Ctrl+O`, `Enter`, `Ctrl+X`).

### Fase 4: EL CANVI CRÍTIC (El Workflow de GitHub Actions)

Si deixem el Workflow de GitHub Actions tal com està, la pròxima vegada que es faci un `git push`, el comandament `rsync --delete` veurà que la clau privada no existeix a GitHub i **l'esborrarà del servidor AWS**.

Per evitar aquest desastre, s'ha d'afegir una simple regla al fitxer `.github/workflows/deploy-backend-prod.yml` dins del pas on fem l'`rsync`:

```yaml
- name: 5. Sincronitzar fitxers amb EC2 (rsync)
  run: |
    rsync -avz --delete \
      -e "ssh -p 22 -o StrictHostKeyChecking=no -i ~/.ssh/deploy_key" \
      --exclude '.git/' --exclude '.github/' \
      --exclude 'var/' --exclude 'tests/' \
      --exclude 'config/secrets/prod/prod.decrypt.private.php' \
      ./ ${{ env.TARGET_USER }}@${{ env.TARGET_HOST }}:/var/www/backend/
```

Fixa't en la nova línia `--exclude 'config/secrets/prod/prod.decrypt.private.php'`. Això li diu al GitHub Runner: _"Sincronitza-ho tot, però sota cap concepte toquis o esborris la clau privada del servidor AWS"_.

---
