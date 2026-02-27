# !!! ⚠️⚠️⚠️⚠️ RECORDATORI: Les credencials s'han de configurar com a secrets al repositori (Settings > Secrets and variables > Actions) CADA VEGADA QUE OBRIM EL LAB D'ACADEMY, ja que caduquen ⚠️⚠️⚠️ !!!

### Guia de passos a tenir en compte per fer un desplegament de la landing page a un bucket S3 amb possibilitat de teniru un CloudFront

## He intentat fer un desplegament únic per a prod i dev, només canviant les variables d'entorn segons la branca. Així evitem tenir dos workflows pràcticament idèntics i mantenim tot més net.
Perquè el desplegament funcioni correctament, has d'entendre què està passant "sota el capó":

1. **Detectar l'esdeveniment (Trigger):** El workflow s'activa automàticament quan es detecta un `push` a les branques `main` o `develop`. També pots llançar-lo manualment.
2. **Assignar el Runner:** GitHub reserva una màquina virtual (ubuntu-latest) on s'executaran totes les comandes.
3. **Determinar l'entorn amb lògica ternària:**
* Si el trigger ve de `main`, el sistema assignarà les variables de **Producció**.
* Si ve de `develop`, el sistema assignarà les de **Desenvolupament**.


4. **Preparar l'espai de treball:** Es descarrega el codi del repositori (checkout) i s'injecten les credencials temporals d'AWS Academy (Secrets).
5. **Sincronització de fitxers:** S'utilitza la comanda `aws s3 sync`. Tingues en compte que els fitxers de configuració de Git (`.git`) s'han d'excloure per seguretat.
6. **Validació de CloudFront:** El sistema comprova si has configurat un ID de distribució. Si la variable està buida, saltarà aquest pas per evitar errors.
7. **Invalidació de la Cache:** Es demana a CloudFront que ignori les còpies antigues dels fitxers i agafi les noves del S3 immediatament.

---

### Configuració necessària a GitHub (Settings > Secrets and variables > Actions)

Abans de fer el primer `push`, assegura't de tenir creats els següents elements a la pestanya **Variables**:

| Variable | Descripció |
| --- | --- |
| `S3_BUCKET_NAME_PROD` | Nom del bucket de producció (ex: `la-meva-landing-prod`) |
| `S3_BUCKET_NAME_DEV` | Nom del bucket de proves (ex: `la-meva-landing-dev`) |
| `CLOUDFRONT_ID_PROD` | ID de la distribució (ex: `E2ABC123...`) |
| `CLOUDFRONT_ID_DEV` | ID de la distribució de dev (si en tens) |
| `AWS_REGION` | La regió (ex: `us-east-1`) |

**Recordatori final:** Recorda que els **Secrets** d'AWS (`Access Key`, `Secret Key` i `Session Token`) caduquen. Si el deploy et dona un error de "Forbidden", el primer que has de fer és revisar si les credencials del laboratori han canviat!

Vols que preparem una petita llista de comprovació (checklist) per als alumnes perquè sàpiguen on trobar aquestes dades a la consola d'AWS?