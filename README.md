# BIGDATASTACK — README

Stack de datos “llave en mano” con **MariaDB**, **Spark (master+workers+history)**, **Airflow (Celery + Flower)**, **Superset**, **JupyterLab**, **MinIO**, **Redis** y **n8n**.  
Incluye un **controller** para levantar/parar todo, preparar volúmenes, chequear salud y crear artefactos base (DAGs, scripts, notebooks).

> ⚠️ Este stack está pensado y probado para **Linux** (por ejemplo Ubuntu 22.04/24.04).  
> En otros sistemas operativos puede requerir ajustes (permisos, rutas, comandos).

---

## ✅ Requisitos previos

En el **host** donde vas a ejecutar `controller.sh` necesitás:

- **Docker** y **Docker Compose**
  - Docker Engine 24+ recomendado
  - `docker compose` (plugin nuevo, no `docker-compose` clásico)
- **Bash**, `curl` y utilidades básicas de línea de comandos
- **Node.js** (el controller lo usa para chequear n8n)
  - Recomendado: **Node.js 18 o superior** (probado con la rama 22.x)
- **ngrok** (solo si vas a usar el modo público `up-public`)
  - Binario accesible como `ngrok` o configurado en `.env` (`N8N_NGROK_BIN`)

Opcional pero recomendado:

- **Git** para versionar el repo
- Navegador moderno (Chrome/Firefox/Edge) para acceder a las UIs

---

## ⚙️ Componentes

| Servicio        | Rol principal                                  | Puerto (host)                               | Notas clave |
|-----------------|-------------------------------------------------|---------------------------------------------|-------------|
| MariaDB         | Base de datos relacional                        | `MARIADB_PORT` (p.ej. 3306 / Adminer 8089)  | Adminer en `http://localhost:8089` |
| MinIO           | S3 compatible (datalake local)                  | `MINIO_CONSOLE_PORT`                        | Usuario/clave en `.env` |
| Spark Master    | Orquestación Spark                              | `SPARK_MASTER_WEBUI_PORT`                   | Historial en `SPARK_HISTORY_PORT` |
| Airflow Web     | Orquestación de workflows                       | `AIRFLOW_PORT`                              | CeleryExecutor + Flower (`5555`) |
| Superset        | BI/Dashboards                                   | `SUPERSET_PORT`                             | Admin/clave en `.env` |
| JupyterLab      | Notebooks                                       | `JUPYTER_PORT`                              | Token en `.env` |
| Redis           | Broker Celery                                   | —                                           | Interno |
| n8n             | Automatizaciones + OAuth (Gmail, etc.)          | `N8N_PORT` (local) / 443 (público via ngrok)| LOCAL por defecto; túnel HTTPS opcional con **ngrok** |

> Nota: Todos los puertos exactos se definen en `.env`. Según la corrección actual, **Airflow usa 8084** para evitar conflicto con otros servicios.

---

## 🗂️ Arquitectura general

Estas imágenes asumen que los SVG están en la carpeta `docs/` del repositorio.

```text
docs/
├─ diagram_arquitectura_bigdatastack.svg
├─ diagram_flujo_dag_airflow_spark.svg
└─ diagram_oauth_n8n_ngrok_gmail.svg
```

### Vista general del stack

![Arquitectura general](docs/diagram_arquitectura_bigdatastack.svg)

### Diagrama de flujo de un DAG típico

![Flujo DAG Airflow → Spark → MariaDB/MinIO](docs/diagram_flujo_dag_airflow_spark.svg)

### Flujo OAuth2 Gmail con n8n + ngrok

![Flujo OAuth Gmail con n8n + ngrok](docs/diagram_oauth_n8n_ngrok_gmail.svg)

---

## 🗂️ Estructura de carpetas

```text
.
├─ controller.sh
├─ docker-compose.yml
├─ .env
├─ docs/                     # Documentación: diagramas, capturas, etc.
├─ plantillas/
│   ├─ dag_test_mariadb.py
│   └─ test_mariadb.py
├─ notebooks/
│   └─ sensores_demo.ipynb
└─ volumenes/
    ├─ superset/
    ├─ jupyterlab/
    ├─ shared/
    │   ├─ dags_airflow/
    │   ├─ scripts_airflow/
    │   └─ spark-events/
    ├─ airflow-logs/
    ├─ airflow-plugins/
    ├─ redis-data/
    └─ n8n-data/
```

El `controller.sh` crea/ajusta permisos en `volumenes/*` y copia plantillas iniciales (`dag_test_mariadb.py`, `test_mariadb.py`, `sensores_demo.ipynb`) a los volúmenes correspondientes.  
La carpeta `docs/` está pensada para incluir diagramas de funcionamiento, capturas de pantalla e info adicional.

---

## 🔐 Variables de entorno (`.env` mínimo)

```ini
# ---- MariaDB
MARIADB_HOST=mariadb
MARIADB_PORT=3306
MARIADB_DATABASE=bigdata_db
MARIADB_USER=bigdata_user
MARIADB_PASSWORD=bigdata_pass
MARIADB_ROOT_PASSWORD=super_root_pass

# ---- Adminer
ADMINER_PORT=8089

# ---- Spark
SPARK_MASTER_WEBUI_PORT=8080
SPARK_HISTORY_PORT=18080

# ---- Airflow
AIRFLOW_PORT=8084
AIRFLOW_ADMIN_USER=admin
AIRFLOW_ADMIN_PASS=adminpass
FERNET_KEY=xxxxx
WEBSERVER_SECRET_KEY=yyyyy
AIRFLOW_DB_CONN=postgresql+psycopg2://airflow:airflow@airflow-db/airflow  # si aplica

# ---- Superset
SUPERSET_PORT=8088
SUPERSET_ADMIN_USER=admin
SUPERSET_ADMIN_PASSWORD=adminpass

# ---- Jupyter
JUPYTER_PORT=8888
JUPYTER_TOKEN=jupytertoken

# ---- MinIO
MINIO_ROOT_USER=minio
MINIO_ROOT_PASSWORD=minio123
MINIO_CONSOLE_PORT=9001

# ---- n8n (modo LOCAL por defecto)
N8N_PORT=5678
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=admin

# ---- ngrok (solo si usás modo PÚBLICO con up-public)
N8N_NGROK_BIN=ngrok
N8N_NGROK_PORT=5678
# N8N_NGROK_DOMAIN=tu-dominio.ngrok-free.app   # opcional con plan ngrok
```

> Importante: variables como `N8N_WEBHOOK_URL`, `N8N_HOST`, `N8N_PROTOCOL` y `WEBHOOK_URL` ya no hace falta definirlas en `.env`.  
> El `controller.sh` las setea en tiempo de ejecución según el modo (LOCAL o PÚBLICO).

---

## 🚀 Uso rápido

```bash
# Modo LOCAL (por defecto, sin ngrok)
./controller.sh           # Big Data + n8n local
./controller.sh up        # equivalente

# Modo PÚBLICO (ngrok + n8n HTTPS externo)
./controller.sh up-public # Big Data + n8n con túnel público

# Utilidades
./controller.sh status     # Muestra estado/URLs
./controller.sh down       # Detiene todo el stack
./controller.sh clean      # Limpia logs/spark-events
./controller.sh full-clean # Limpia TODO (cuidado)
```

---

## 🧠 Lógica del `controller.sh`

### Modo LOCAL (por defecto: `./controller.sh` o `./controller.sh up`)

1. Crea estructura de `volumenes/*` y ajusta permisos.
2. No arranca ngrok.
3. Fuerza variables de n8n a entorno local:

   ```bash
   N8N_PROTOCOL=http
   N8N_HOST=localhost
   N8N_WEBHOOK_URL=http://localhost:${N8N_PORT}
   WEBHOOK_URL="$N8N_WEBHOOK_URL"
   WEBHOOK_TUNNEL_URL="$N8N_WEBHOOK_URL"
   N8N_EDITOR_BASE_URL="$N8N_WEBHOOK_URL"
   ```

4. Ejecuta:

   ```bash
   docker compose --env-file .env -f docker-compose.yml up -d --build
   ```

5. Espera y verifica:
   - MariaDB
   - Spark Master
   - Superset
   - JupyterLab
   - Airflow Web (`/health`)
   - Flower
   - n8n (vía `/rest/health` o HTTP básico usando `node`)

6. Si es necesario:
   - Inicializa DB de Airflow (`airflow db init`).
   - Crea conexión `spark_default` si no existe.

7. Imprime URLs locales (incluyendo `http://localhost:${N8N_PORT}`) y datos de acceso.

### Modo PÚBLICO (`./controller.sh up-public`)

1. Crea estructura de `volumenes/*` y ajusta permisos.
2. Arranca ngrok antes de `docker compose`:

   ```bash
   N8N_NGROK_BIN=ngrok          # o lo que definas en .env
   N8N_NGROK_PORT=5678          # o el puerto que uses para n8n
   ```

3. Consulta la API local de ngrok (`http://127.0.0.1:4040/api/tunnels`) y obtiene una URL pública:

   ```text
   https://xxxxx.ngrok-free.app
   ```

4. Exporta variables para n8n:

   ```bash
   N8N_WEBHOOK_URL="https://xxxxx.ngrok-free.app"
   N8N_HOST="xxxxx.ngrok-free.app"
   N8N_PROTOCOL="https"
   N8N_PORT="443"
   ```

5. Levanta el stack con:

   ```bash
   docker compose --env-file .env -f docker-compose.yml up -d --build
   ```

6. Hace los mismos healthchecks que en modo local (MariaDB, Spark, Superset, Jupyter, Airflow, Flower, n8n).

7. Muestra:
   - URLs locales (Adminer, Airflow, Superset, Jupyter, etc.).
   - URL pública de n8n via ngrok + credenciales de Basic Auth.
   - URLs a usar en OAuth (redirect y origin).

---

## 🌐 n8n + ngrok + OAuth (Gmail)

### Modo LOCAL (sin ngrok, por defecto)

- n8n corre en: `http://localhost:${N8N_PORT}` → típicamente `http://localhost:5678`.

En Google Cloud OAuth 2.0 podés usar:

- **Redirect URI:**

  ```text
  http://localhost:5678/rest/oauth2-credential/callback
  ```

- **Origin:**

  ```text
  http://localhost:5678
  ```

> Solo funciona en local; no es accesible desde internet.

### Modo PÚBLICO (con ngrok, usando `up-public`)

Una vez que el controller arranca ngrok y levanta el stack, vas a ver algo del estilo:

```text
N8N_WEBHOOK_URL=https://xxxxx.ngrok-free.app
```

En Google Cloud OAuth 2.0 usás:

- **Authorized redirect URIs**

  ```text
  https://xxxxx.ngrok-free.app/rest/oauth2-credential/callback
  ```

- **Authorized JavaScript origins**

  ```text
  https://xxxxx.ngrok-free.app
  ```

Así n8n puede recibir callbacks de OAuth (Gmail, etc.) desde internet usando el túnel de ngrok.

---

## 🧪 DAG de prueba: `dag_test_mariadb`

- DAG: `volumenes/shared/dags_airflow/dag_test_mariadb.py`
- Script: `volumenes/shared/scripts_airflow/test_mariadb.py`
- Driver JDBC: `mariadb-java-client.jar` incluido en la imagen de Spark (por ejemplo en `/opt/spark/jars/`)

Comando que ejecuta el script (ejemplo dentro de un contenedor Spark):

```bash
/opt/spark/bin/spark-submit   --master spark://spark-master:7077   /opt/spark/app/test_mariadb.py
```

URL JDBC estable (tipos correctos, sin castear manual):

```python
JDBC_URL = (
    f"jdbc:mysql://{DB_HOST}:{DB_PORT}/{DB_NAME}"
    "?useUnicode=true"
    "&permitMysqlScheme=true"
    "&characterEncoding=utf8"
    "&serverTimezone=UTC"
    "&tinyInt1isBit=false"
    "&zeroDateTimeBehavior=convertToNull"
)
```

Con esto Spark infiere correctamente:

- `id: integer`
- `dispositivo: string`
- `temperatura: decimal(5,2)`
- `humedad: decimal(5,2)`
- `fecha: timestamp`

---

## 🩺 Healthchecks y esperas

- **n8n**:
  - El controller usa Node.js para golpear `/rest/health` o la raíz HTTP.
  - Asegurate de tener `node` instalado y en el `PATH`.
- **Spark**:
  - UI en `http://localhost:${SPARK_MASTER_WEBUI_PORT}`.
  - Spark History en `http://localhost:${SPARK_HISTORY_PORT}` leyendo eventos desde `volumenes/shared/spark-events/`.
- **Airflow**:
  - El controller espera a que `/health` responda antes de continuar.
  - Si es la primera vez, ejecuta `airflow db init` dentro del contenedor.
  - Crea la conexión `spark_default` si no existe.

---

## 📚 Datos de ejemplo (`sensores`)

```sql
CREATE TABLE IF NOT EXISTS sensores (
  id INT PRIMARY KEY AUTO_INCREMENT,
  dispositivo VARCHAR(64) NOT NULL,
  temperatura DECIMAL(5,2) NOT NULL,
  humedad DECIMAL(5,2) NOT NULL,
  fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO sensores (dispositivo, temperatura, humedad, fecha) VALUES
("sensor_norte", 22.50, 60.10, NOW()),
("sensor_sur",   25.30, 55.40, NOW()),
("sensor_este",  21.80, 58.90, NOW()),
("sensor_oeste", 24.10, 52.20, NOW());
```

---

## ✅ Checklist rápido

- Docker y Docker Compose instalados
- Node.js (>=18) instalado y accesible como `node`
- ngrok instalado (si vas a usar `up-public`)
- `.env` configurado con puertos/usuarios/contraseñas
- `./controller.sh` con permisos de ejecución (`chmod +x controller.sh`)
- Airflow en `http://localhost:${AIRFLOW_PORT}`
- Spark UI en `http://localhost:${SPARK_MASTER_WEBUI_PORT}`
- Superset en `http://localhost:${SUPERSET_PORT}`
- Jupyter en `http://localhost:${JUPYTER_PORT}`
- Adminer en `http://localhost:8089`
- n8n en `http://localhost:${N8N_PORT}` (modo LOCAL) o URL de ngrok (modo PÚBLICO)
- DAG `dag_test_mariadb` muestra filas de `sensores` con esquema correcto
