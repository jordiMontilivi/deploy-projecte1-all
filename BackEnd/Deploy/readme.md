# 🚀 Guia de Desplegament: Symfony API a AWS EC2 (Bare Metal)

Aquest projecte inclou la configuració automatitzada (CI/CD) per desplegar el nostre backend a dos entorns diferents: **Develop** (per proves) i **Producció** (entorn real).

## 🌍 Entorns i Arquitectura

| Entorn   | Branca Git | Servidor EC2 | Base de Dades         | Gestió de Secrets          |
| -------- | ---------- | ------------ | --------------------- | -------------------------- |
| **DEV**  | `develop`  | IP_EC2_DEV   | MySQL Local / RDS Dev | Fitxer `.env.local` manual |
| **PROD** | `main`     | IP_EC2_PROD  | AWS RDS MySQL         | Symfony Secrets Vault      |

---

## 🛠️ PAS 1: Preparació del Servidor (Cosa d'una vegada)

Abans de fer l'autodesplegament, el servidor EC2 ha d'estar configurat.

1. Connecta't per SSH a la teva màquina EC2.
2. Crea un fitxer `setup.sh`, enganxa l'script de l'AMI i executa'l amb `sudo bash setup.sh`.
3. Verifica que accedint a la IP pública del servidor veus el missatge "SERVIDOR LLEST".

---

## 🔐 PAS 2: Gestió de Secrets (Contrasenyes de BD)

Com que el repositori és públic/compartit, **MAI** pugem contrasenyes al codi.

### Per a l'Entorn de Desenvolupament (DEV)

1. Connecta't amb un client SFTP (Termius, FileZilla) a la teva EC2 de Dev.
2. Ves a la ruta `/var/www/backend/`.
3. Puja el teu fitxer `.env.local` que conté la teva `DATABASE_URL`.
   _El workflow de GitHub farà servir aquest fitxer cada vegada que desplegui._

### Per a l'Entorn de Producció (PROD) - Professional 🌟

Utilitzem el sistema de xifrat natiu de Symfony:

1. Al teu ordinador local executa: `php bin/console secrets:set DATABASE_URL` i posa la ruta de la RDS d'AWS.
2. Puja els canvis a GitHub (es pujaran els fitxers a `config/secrets/prod/`).
3. **El pas crític:** Obre SFTP contra la EC2 de Producció.
4. Agafa el fitxer local `config/secrets/prod/prod.decrypt.private.php` (la clau privada que desxifra els secrets) i puja'l EXACTAMENT a la mateixa ruta al teu servidor de Producció.
   _Ara, quan l'aplicació arrenqui a Producció, llegirà la base de dades xifrada de Git i la desxifrarà internament._

---

## 🤖 PAS 3: Entendre els Workflows (GitHub Actions)

- **Com funciona DEV?** Quan fem un _push_ a `develop`, el servidor descarrega el codi net i executa el `composer install` dins del propi servidor per baixar-se les llibreries.
- **Com funciona PROD?** A producció busquem zero temps d'inactivitat i seguretat. El codi i les llibreries (la carpeta `vendor`) es "compilen" dins dels servidors de GitHub. Després s'envia el paquet tancat al servidor i només es recarrega la caché i la base de dades.

## ⚠️ Possibles Problemes

- **Error 500 a Apache:** Revisa els logs amb `cat /var/log/apache2/backend_error.log`.
- **Permisos Denegats a `var/cache`:** Assegura't que l'script d'ACLs (`setfacl`) ha funcionat correctament.
