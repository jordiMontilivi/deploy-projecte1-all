
tinc este script complet, vull poder configurar el front i el back per a 
en dev poder configurar les variables del backend .env.dev per a accedir a les dades sensibles configurant cors ja que tenim ports diferents en la mateix AMI EC2, voldria tenir les variables sensibles de backend a .env.dev
en prod volia fer un reverse proxy (si ho veus convenient) per configurar les dues maquines EC2 diferents a diferent ip i Apache diferent on haig de permetre fer les conexions front i back, com haig de fer les peticions a /api de front a back... voldria tenir les variables sensibles a secrets de symfony 
Pensant que les ips de front i back canvien canda vegada que fem un desplegament o aturem el laboratori, quins canvis haig de fer a l'script i al desplegament de github actions per a poder comunicar-se front i back tant en dev com prod. si faig un proxy reverse haig de canviar la ip de proxy reverse? havia pensat fer un deploy en frontend per canviar aquesta nova ip
quines variables i configuracions he de fer en front vuejs i back symfony per a poder fer els desplegaments? variables entorn, .env... 


l teu cas té **3 problemes típics** en pràctiques amb **Amazon EC2** i **AWS Academy**:

1. **IPs públiques canvien**
2. **Frontend (Vue.js) i backend (Symfony) separats**
3. **configuració diferent dev vs prod**

La solució neta és separar **DEV** i **PROD** arquitectònicament.

---

# 1️⃣ DEV (mateixa EC2, ports diferents)

Arquitectura:

```
EC2
 ├─ Apache
 │   ├─ frontend → :80
 │   └─ backend → :8000
```

Frontend crida backend així:

```
http://IP_EC2:8000/api
```

### CORS a Symfony

Instal·la **NelmioCorsBundle**.

config:

```
config/packages/nelmio_cors.yaml
```

```yaml
nelmio_cors:
    defaults:
        allow_origin: ['http://localhost', 'http://127.0.0.1', 'http://IP_EC2']
        allow_methods: ['GET','POST','PUT','DELETE','OPTIONS']
        allow_headers: ['Content-Type','Authorization']
    paths:
        '^/api/':
            allow_origin: ['*']
```

---

### `.env.dev` Symfony

Aquí poses **variables sensibles de dev**.

```
DATABASE_URL=mysql://user:pass@127.0.0.1:3306/app
JWT_SECRET=devsecret
CORS_ALLOW_ORIGIN=http://IP_EC2
```

---

### Vue.js `.env.development`

```
VITE_API_URL=http://IP_EC2:8000/api
```

Axios:

```javascript
const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL
})
```

---

# 2️⃣ PROD (2 EC2 separades)

Arquitectura recomanada:

```
EC2 FRONT
  Apache
  Vue build

EC2 BACK
  Apache
  Symfony API
```

Frontend crida backend així:

```
http://BACK_IP/api
```

---

# 3️⃣ Problema de IPs canviants

Com que AWS Academy canvia IPs, **no pots hardcodejar-les**.

Solució: **variables d'entorn al deploy**.

---

# Backend `.env.prod`

```
APP_ENV=prod
APP_SECRET=xxx

CORS_ALLOW_ORIGIN=http://FRONT_IP
```

---

# Symfony secrets (prod)

Utilitza:

```bash
php bin/console secrets:set DATABASE_URL
php bin/console secrets:set JWT_SECRET
```

Symfony ho guarda xifrat.

---

# Vue `.env.production`

A build:

```
VITE_API_URL=http://BACK_IP/api
```

---

# 4️⃣ Github Actions deploy

Has de passar les IPs com a variables.

Exemple:

```
FRONT_IP
BACK_IP
```

workflow:

```yaml
env:
  VITE_API_URL: http://${{ secrets.BACK_IP }}/api
```

---

# 5️⃣ Reverse proxy (opció millor)

Jo ho faria així:

```
frontend EC2
   Apache
      / → Vue
      /api → proxy → backend EC2
```

Config Apache frontend:

```apache
ProxyPreserveHost On
ProxyPass /api http://BACK_IP
ProxyPassReverse /api http://BACK_IP
```

Frontend crida simplement:

```
/api/products
```

Avantatges:

* no hi ha CORS
* Vue no necessita saber la IP backend
* només canvies config Apache.

---

# ❗ Problema amb IPs canviants

Sí, amb proxy hauràs de **canviar la IP backend**:

```
ProxyPass /api http://NEW_BACK_IP
```

Solució: el teu **script de deploy ja ho pot fer**.

Exemple:

```
BACKEND_IP=$(curl ifconfig.me)
```

o passar-la via **GitHub secrets**.

---

# 6️⃣ Configuració final recomanada

## Vue

`.env.development`

```
VITE_API_URL=http://IP_EC2:8000/api
```

`.env.production`

```
VITE_API_URL=/api
```

---

## Symfony

`.env.dev`

```
CORS_ALLOW_ORIGIN=http://IP_EC2
```

`.env.prod`

sense secrets.

---

Secrets Symfony:

```
DATABASE_URL
JWT_SECRET
```

---

# 7️⃣ Canvis al teu script

### eliminar ServerName fix

```
ServerName localhost
```

o eliminar-lo.

---

### afegir proxy (prod)

```
a2enmod proxy
a2enmod proxy_http
```

---

### backend VirtualHost

```
AllowOverride All
```

---

# 🧠 Recomanació real (molt usada)

Arquitectura:

```
Frontend EC2
  Apache
     Vue build
     reverse proxy → backend

Backend EC2
  Apache
     Symfony API
```

Vue sempre crida:

```
/api
```

i **mai coneix la IP del backend**.

---

✅ Si vols, et puc escriure també:

* **l'script Apache complet corregit (dev + prod)**
* **workflow GitHub Actions complet**
* **estructura `.env` Vue + Symfony perfecta**

(perquè amb AWS Academy hi ha **una arquitectura que evita tocar IPs manualment cada deploy**).
