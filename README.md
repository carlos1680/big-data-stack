# Big Data Stack (Docker Compose) — MariaDB + Spark + Airflow + Superset + Jupyter + MinIO + n8n + Kafka

Repositorio **demo/portfolio** para levantar un entorno Big Data “end-to-end” en **un solo `docker compose`**.
La idea es poder practicar (y mostrar) ingestión, procesamiento distribuido, orquestación y BI, sin depender de cloud.

## 🚀 ¿Qué incluye?

- **MariaDB** (fuente de datos + DBs de Airflow/Superset)
- **Adminer** (UI para DB)
- **MinIO** (S3-compatible / datalake)
- **Apache Kafka** (+ **Zookeeper**) (streaming / event bus)
- **Apache Spark** (master + 2 workers + history server)
- **JupyterLab** (conectado a Spark)
- **Apache Superset** (BI / dashboards)
- **Apache Airflow** (CeleryExecutor + Redis) + **Flower**
- **n8n** (automatización/workflows)

> ✅ Nota: el archivo real `.env` **NO se sube** (está en `.gitignore`). Se usa **`.env.template`** como plantilla.

---

## ✅ Requisitos

- Docker Engine + Docker Compose plugin
- Ngrok, si quiere usar N8N publico
- Nodejs 
- 8 GB RAM mínimo (ideal 16 GB si vas a correr Spark + Superset + Airflow juntos)
- Puertos libres: 3306, 8080-8082, 8088-8090, 8888, 9000-9001, 5555, 5678, **9092**, **2181**

---

## 🏁 Quick start

### 1) Crear tu `.env` desde la plantilla
```bash
cp .env.template .env
```

### 2) Generar claves (Superset / Airflow / n8n)
Ejecutá estos comandos y pegá los valores en tu `.env`:

**Superset secret key** → `SUPERSET_SECRET_KEY`
```bash
python - <<'PY'
import secrets
print(secrets.token_urlsafe(64))
PY
```

**Airflow fernet key** → `AIRFLOW__CORE__FERNET_KEY`
```bash
python - <<'PY'
from cryptography.fernet import Fernet
print(Fernet.generate_key().decode())
PY
```

**Airflow webserver secret / n8n encryption key** → `AIRFLOW__WEBSERVER__SECRET_KEY` y `N8N_ENCRYPTION_KEY`
```bash
python - <<'PY'
import secrets
print(secrets.token_urlsafe(32))
PY
```

> Si te falta `cryptography` para generar el fernet key:
> ```bash
> python -m pip install cryptography
> ```

### 3) Administrar el stack
#### ./controller.sh help ####
⚙️  Cargando variables desde .env...
Uso: 
- ./controller.sh {up [--debug-build]|up-public|down|status|clean|full-clean}
- (sin parámetro)  -> Big Data + n8n LOCAL (sin ngrok, http://localhost)
- up               -> igual que sin parámetro (modo local)
- up --debug-build -> (LOCAL) rebuild con logs completos de build (RUN echo, etc.) + log en ./volumenes/controller-- - - up-public        -> Big Data + n8n PÚBLICO (ngrok + HTTPS)

## 🌐 URLs (local)

| Servicio | URL |
|---|---|
| Adminer | http://localhost:8089 |
| MinIO Console | http://localhost:9001 |
| MinIO API | http://localhost:9000 |
| Spark Master UI | http://localhost:8080 |
| Spark Worker 1 UI | http://localhost:8081 |
| Spark Worker 2 UI | http://localhost:8082 |
| Spark History | http://localhost:18080 |
| Superset | http://localhost:8088 |
| JupyterLab | http://localhost:8888 |
| Airflow | http://localhost:8090 |
| Flower | http://localhost:5555 |
| n8n | http://localhost:5678 |

### Kafka / Zookeeper (nota)
Kafka **no** expone una UI web por defecto (no es `http://localhost:9092/`).
Se accede vía clientes Kafka:

- **Desde el host:** `localhost:9092`
- **Desde contenedores en la red:** `kafka-broker:9092`
- **Zookeeper (si aplica):** `localhost:2181` (host) / `zookeeper:2181` (docker network)

> Credenciales: usá las del `.env` (por defecto el user suele ser `admin` y la pass la definís vos).

---

## 🧪 Ejemplo rápido (para mostrar que funciona)

### A) Cargar datos en MariaDB
Este repo incluye scripts en `init-sql/`.
Podés conectarte desde Adminer o desde tu host:

```bash
docker exec -it mariadb mysql -u${MARIADB_USER} -p${MARIADB_PASSWORD} ${MARIADB_DATABASE}
```

### B) Probar Kafka (crear topic + producir/consumir)
Ejemplo simple usando el container de Kafka:

Crear topic:
```bash
docker exec -it kafka-broker bash -lc "kafka-topics --bootstrap-server kafka-broker:9092 --create --topic test_topic --partitions 1 --replication-factor 1"
```

Producir mensajes:
```bash
docker exec -it kafka-broker bash -lc "kafka-console-producer --bootstrap-server kafka-broker:9092 --topic test_topic"
```

Consumir mensajes (en otra terminal):
```bash
docker exec -it kafka-broker bash -lc "kafka-console-consumer --bootstrap-server kafka-broker:9092 --topic test_topic --from-beginning"
```

### C) Probar Spark desde Jupyter
Abrí Jupyter y ejecutá el notebook de ejemplo:
- `notebooks/sensores_demo.ipynb`


---

## 🔒 Seguridad / buenas prácticas (importante)

- Nunca subas `.env` al repo.
- No subas archivos OAuth / credenciales (`client_secret*.json`, `credentials*.json`, etc.).
- Si alguna vez pegaste un secreto en Git por error: **rotalo** (cambiarlo) y reescribí historial si hace falta.

---

## 📌 Sugerencia de `.gitignore` (extra)
Si querés dejarlo más completo, podés agregar:
- `.venv/`, `venv/`
- `.pytest_cache/`, `.ruff_cache/`
- `*.sqlite`, `*.db`
- `*.parquet`, `*.csv` (si son datasets grandes o sensibles)

---

## 📄 Licencia
MIT.
