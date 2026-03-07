# Backend Symfony

## 🚀 Guia Ràpida: Desplegament del Backend (Symfony a AWS EC2)

Aquesta guia resumeix els passos essencials per desplegar el backend de forma **segura i automatitzada** mitjançant **GitHub Actions**, aplicant bones pràctiques d'administració de sistemes.

---

# 1️⃣ Preparació del servidor (AWS EC2)

⚠️ **Aquest pas només s'ha de fer una vegada a la vida del servidor.**

Els passos ja estan automatitzats al nostre script `full-setup.sh`, però es mostren manualment per entendre el procés.

## 1. Connectar-se al servidor

```bash
ssh -i la_teva_clau.pem ubuntu@IP_DEL_TEU_SERVIDOR
```

## 2. Copiar l'script de configuració

```bash
scp -i la_teva_clau.pem full-setup.sh ubuntu@IP_DEL_TEU_SERVIDOR:/home/ubuntu/
```

**Alternativa:** crear-lo directament al servidor:

```bash
nano full-setup.sh
```

(enganxa el contingut i desa el fitxer)

## 3. Executar l'script

```bash
sudo bash full-setup.sh prod backend
```

Paràmetres possibles:

- `prod`
- `dev`
- `backend`
- `frontend`
- `all`

## 4. Verificar Apache

```bash
sudo systemctl status apache2
```

## 5. Eliminar l'script per seguretat

```bash
rm -f full-setup.sh
```

---

# 2️⃣ Configuració de variables sensibles

Consulta el document:

```
readme-env.md
```

Aquest explica detalladament la gestió de secrets segons l'entorn.

---

## 🧪 Entorn DEV

En desenvolupament utilitzem el fitxer:

```
.env.local
```

Tasques:

1. Crear el fitxer `.env.local`
2. Afegir les variables d'entorn necessàries
3. Gestionar-lo només en local

⚠️ **Important**

- Aquest fitxer **no s'ha de pujar al repositori**
- Ha d'estar inclòs al `.gitignore`

---

## 🔐 Entorn PROD

A producció utilitzem dues capes de seguretat:

- fitxer de secrets del servidor
- sistema de secrets de Symfony

---

### 2.1 Fitxer de secrets del servidor

Crear el fitxer:

```
backend-secrets.conf
```

Aquest contindrà informació sensible com:

- credencials de base de dades
- API keys
- tokens

#### Passos

1. Crear el fitxer al backend
2. Afegir les variables sensibles
3. Modificar els permisos

⚠️ Els usuaris `ubuntu` i `www-data` **no han de tenir permisos de lectura**.

Només **Apache amb root** ha de poder accedir-hi.

---

### 2.2 Secrets de Symfony

Symfony permet guardar secrets **xifrats dins del projecte**.

#### Generar claus criptogràfiques

📍 Executar **a l'ordinador local**

```bash
php bin/console secrets:generate-keys --env=prod
```

---

#### Afegir secrets

Exemple: connexió a la base de dades

```bash
php bin/console secrets:set DATABASE_URL --env=prod
```

Symfony guardarà el secret **xifrat** dins del projecte.

---

#### Copiar la clau privada al servidor

Fitxer local:

```
config/secrets/prod/prod.decrypt.private.php
```

Destí al servidor EC2:

```
/var/www/backend/config/secrets/prod/prod.decrypt.private.php
```

⚠️ **Important**

- Aquest fitxer **no s'ha de pujar al repositori**
- Només ha d'existir al servidor de producció

---

# 3️⃣ Configuració de GitHub Actions

Preparem el repositori perquè pugui comunicar-se amb el servidor EC2.

## Afegir secrets al repositori

Anar a:

```
GitHub → Settings → Secrets and variables → Actions
```

Afegir els següents **Repository Secrets**:

| Secret      | Descripció                                |
| ----------- | ----------------------------------------- |
| TARGET_HOST | IP pública o domini del servidor EC2      |
| TARGET_USER | Usuari del servidor (normalment `ubuntu`) |
| TARGET_KEY  | Contingut complet del fitxer `.pem`       |

---

## Configurar exclusió a rsync

Al workflow:

```
.github/workflows/deploy-backend-prod.yml
```

Afegir l'exclusió per evitar esborrar la clau privada:

```bash
--exclude 'config/secrets/prod/prod.decrypt.private.php'
```

---

# 4️⃣ Desplegament

A partir d'aquest punt el desplegament és **100% automatitzat**.

## 1. Afegir canvis

```bash
git add .
```

## 2. Crear commit

```bash
git commit -m "Preparant llançament a Producció"
```

## 3. Enviar a GitHub

```bash
git push origin main
```

---

## 4. Execució automàtica

Anar a:

```
GitHub → Actions
```

Allà veuràs el procés de desplegament:

- GitHub descarrega el codi
- s'executa el runner Ubuntu
- s'instal·la PHP (`setup-php`)
- s'executa Composer
- s'envien fitxers via `rsync`
- s'executen migracions
- es neteja la cache

---

# ✅ Verificació final

Comprova que el backend està operatiu al servidor de producció.
