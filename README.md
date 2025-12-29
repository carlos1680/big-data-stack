# Big Data Stack (Docker Compose) — MariaDB + Spark + Airflow + Superset + Jupyter + MinIO + n8n

Repositorio **demo/portfolio** para levantar un entorno Big Data “end-to-end” en **un solo `docker compose`**.
La idea es poder practicar (y mostrar) ingestión, procesamiento distribuido, orquestación y BI, sin depender de cloud.

## 🚀 ¿Qué incluye?

- **MariaDB** (fuente de datos + DBs de Airflow/Superset)
- **Adminer** (UI para DB)
- **MinIO** (S3-compatible)
- **Apache Spark** (master + 2 workers + history server)
- **JupyterLab** (conectado a Spark)
- **Apache Superset** (BI / dashboards)
- **Apache Airflow** (CeleryExecutor + Redis) + **Flower**
- **n8n** (automatización/workflows)

> ✅ Nota: el archivo real `.env` **NO se sube** (está en `.gitignore`). Se usa **`.env.template`** como plantilla.

---

## ✅ Requisitos

- Docker Engine + Docker Compose plugin
- 8 GB RAM mínimo (ideal 16 GB si vas a correr Spark + Superset + Airflow juntos)
- Puertos libres: 3306, 8080-8082, 8088-8090, 8888, 9000-9001, 5555, 5678

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

### 3) Levantar el stack
Opción A (recomendada si usás el controlador):
```bash
chmod +x controller.sh
./controller.sh up
```

Opción B (directo con compose):
```bash
docker compose up -d
```

### 4) Verificar
```bash
docker compose ps
docker compose logs -f --tail=200
```

---

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

> Credenciales: usá las del `.env` (por defecto el user suele ser `admin` y la pass la definís vos).

---

## 🧪 Ejemplo rápido (para mostrar que funciona)

### A) Cargar datos en MariaDB
Este repo incluye scripts en `init-sql/`.
Podés conectarte desde Adminer o desde tu host:

```bash
docker exec -it mariadb mysql -u${MARIADB_USER} -p${MARIADB_PASSWORD} ${MARIADB_DATABASE}
```

### B) Probar Spark desde Jupyter
Abrí Jupyter y ejecutá el notebook de ejemplo:
- `notebooks/sensores_demo.ipynb`

---

## 🧹 Apagar y limpiar

Parar contenedores:
```bash
docker compose down
```

Borrar **volúmenes** (⚠️ borra datos locales):
```bash
docker compose down -v
```

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
MIT (o la que prefieras).