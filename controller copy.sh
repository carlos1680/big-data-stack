docker#!/bin/bash
set -Eeuo pipefail

# ==========================================================
# 🧠 CONTROLADOR DE ENTORNO BIG DATA (Bruno Piriz)
# ==========================================================

ENV_FILE=".env"
COMPOSE_FILE="docker-compose.yml"
MECHABIOS_COMPOSE_FILE="mechabios/docker-compose-infraestructura.yaml"

# Nombres de proyecto para separar stacks en Docker Compose
BIGDATA_PROJECT_NAME="${BIGDATA_PROJECT_NAME:-bigdata}"
MECHABIOS_PROJECT_NAME="${MECHABIOS_PROJECT_NAME:-mechabios}"

# 🎨 Colores
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

# ==========================================================
# ⚙️ CARGAR VARIABLES .ENV
# ==========================================================
if [ -f "$ENV_FILE" ]; then
  echo -e "${YELLOW}⚙️  Cargando variables desde $ENV_FILE...${RESET}"
  # shellcheck disable=SC2046
  export $(grep -v '^#' "$ENV_FILE" | xargs)
else
  echo -e "${RED}❌ No se encontró $ENV_FILE. Abortando.${RESET}"
  exit 1
fi

# ==========================================================
# 🧩 VERIFICACIÓN DE VOLÚMENES Y ARCHIVOS BASE
# ==========================================================
fix_volumes() {
  echo -e "${YELLOW}🧩 Verificando estructura de volúmenes locales...${RESET}"

  mkdir -p volumenes/{superset,jupyterlab,shared,airflow-logs,airflow-plugins,redis-data,n8n-data}
  mkdir -p volumenes/shared/{dags_airflow,scripts_airflow,spark-events}

  echo -e "${YELLOW}🔧 Ajustando permisos en carpetas de trabajo...${RESET}"
  chmod -R 777 volumenes/superset volumenes/jupyterlab volumenes/shared volumenes/airflow-logs volumenes/airflow-plugins volumenes/redis-data volumenes/n8n-data 2>/dev/null || true
  echo -e "${GREEN}✅ Permisos aplicados correctamente a carpetas de usuario.${RESET}"
  echo -e "${YELLOW}⚠️  Carpetas protegidas (MariaDB y MinIO) no fueron modificadas para evitar errores.${RESET}"

  # Notebook de ejemplo
  if [ -f "./notebooks/sensores_demo.ipynb" ] && [ ! -f "./volumenes/jupyterlab/sensores_demo.ipynb" ]; then
    cp ./notebooks/sensores_demo.ipynb ./volumenes/jupyterlab/
    chmod 666 ./volumenes/jupyterlab/sensores_demo.ipynb
    echo -e "${GREEN}📘 Notebook de ejemplo copiado.${RESET}"
  fi

  # DAGs y scripts
  if [ -f "./plantillas/dag_test_mariadb.py" ]; then
    cp -f ./plantillas/dag_test_mariadb.py ./volumenes/shared/dags_airflow/
    chmod 666 ./volumenes/shared/dags_airflow/dag_test_mariadb.py
  fi
  if [ -f "./plantillas/test_mariadb.py" ]; then
    cp -f ./plantillas/test_mariadb.py ./volumenes/shared/scripts_airflow/
    chmod 666 ./volumenes/shared/scripts_airflow/test_mariadb.py
  fi

  echo -e "${GREEN}✅ Volúmenes y archivos base verificados.${RESET}"
}

# ==========================================================
# ⏳ UTILIDADES DE ESPERA
# ==========================================================
wait_for_http() {
  local port="$1"
  local path="${2:-/}"
  local label="${3:-Servicio HTTP}"
  local max_attempts=15
  local sleep_time=5

  echo -e "${YELLOW}⏳ Esperando ${label} en http://localhost:${port}${path} ...${RESET}"
  for i in $(seq 1 $max_attempts); do
    if curl -sf "http://localhost:${port}${path}" >/dev/null 2>&1; then
      echo -e "${GREEN}✅ ${label} respondió.${RESET}"
      return 0
    fi
    echo -e "${YELLOW}⌛ Intento $i/$max_attempts - esperando ${sleep_time}s...${RESET}"
    sleep $sleep_time
  done
  echo -e "${RED}❌ ${label} no respondió a tiempo.${RESET}"
  return 1
}

wait_for_service() {
  local container=$1
  local message=$2
  local max_attempts=15
  local sleep_time=5

  echo -e "${YELLOW}⏳ Esperando ${message}...${RESET}"

  for i in $(seq 1 $max_attempts); do
    # Caso especial: Spark Master por puerto de UI (mapeado al host)
    if [[ "$container" == "spark-master" ]]; then
      if curl -sf "http://localhost:${SPARK_MASTER_WEBUI_PORT}" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ ${message} está listo (UI en puerto ${SPARK_MASTER_WEBUI_PORT}).${RESET}"
        return 0
      fi
    # Caso general: contenedores con healthcheck
    elif docker ps --filter "name=${container}" --filter "health=healthy" | grep -q "${container}"; then
      echo -e "${GREEN}✅ ${message} está listo.${RESET}"
      return 0
    fi
    echo -e "${YELLOW}⌛ Intento $i/$max_attempts - esperando ${sleep_time}s...${RESET}"
    sleep $sleep_time
  done

  echo -e "${RED}❌ ${message} no respondió a tiempo.${RESET}"
  return 1
}

# ✅ FLOWER
wait_for_flower() {
  local name="airflow-flower"
  local max_attempts=15
  local sleep_time=5

  if ! docker ps -a --format '{{.Names}}' | grep -q "^${name}$"; then
    return 0
  fi

  echo -e "${YELLOW}⏳ Esperando Flower UI...${RESET}"
  for i in $(seq 1 $max_attempts); do
    if docker inspect "${name}" --format '{{.State.Health.Status}}' >/dev/null 2>&1; then
      if docker ps --filter "name=${name}" --filter "health=healthy" | grep -q "${name}"; then
        echo -e "${GREEN}✅ Flower UI listo (health=healthy).${RESET}"
        return 0
      fi
    else
      if curl -sf "http://localhost:5555/" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Flower UI respondió por HTTP (5555).${RESET}"
        return 0
      fi
    fi
    echo -e "${YELLOW}⌛ Intento $i/$max_attempts - esperando ${sleep_time}s...${RESET}"
    sleep $sleep_time
  done
  echo -e "${RED}❌ Flower UI no respondió a tiempo.${RESET}"
  return 1
}

# ✅ NUEVO → N8N (sin curl; acepta 200/301/302/401 y /rest/health)
wait_for_n8n() {
  local max_attempts=30
  local sleep_time=3

  # Detecta puerto publicado en el host para 5678/tcp
  local host_port
  host_port="$(docker inspect n8n -f '{{range $p, $cfg := .NetworkSettings.Ports}}{{if eq $p "5678/tcp"}}{{(index $cfg 0).HostPort}}{{end}}{{end}}' 2>/dev/null || true)"
  [ -z "$host_port" ] && host_port="5678"

  local url_local="http://localhost:${host_port}"

  echo -e "${YELLOW}⏳ Esperando interfaz de n8n en ${url_local} ...${RESET}"
  for i in $(seq 1 $max_attempts); do
    node -e "require('http').get('${url_local}/rest/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))" \
      || node -e "require('http').get('${url_local}',r=>process.exit([200,301,302,401].includes(r.statusCode)?0:1)).on('error',()=>process.exit(1))"
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}✅ n8n respondió correctamente en ${url_local}.${RESET}"
      return 0
    fi
    echo -e "${YELLOW}⌛ Intento $i/$max_attempts - esperando ${sleep_time}s...${RESET}"
    sleep $sleep_time
  done
  echo -e "${RED}❌ n8n no respondió a tiempo en ${url_local}.${RESET}"
  return 1
}

# ==========================================================
# 🔌 NGROK PARA N8N (túnel antes de levantar n8n)
# ==========================================================
NGROK_PIDFILE=".ngrok-n8n.pid"

stop_ngrok_for_n8n() {
  if [ -f "$NGROK_PIDFILE" ]; then
    PID="$(cat "$NGROK_PIDFILE" || true)"
    if [ -n "${PID:-}" ] && ps -p "$PID" >/dev/null 2>&1; then
      echo -e "${YELLOW}🔌 Cerrando túnel ngrok (PID ${PID})...${RESET}"
      kill "$PID" 2>/dev/null || true
      sleep 1
    fi
    rm -f "$NGROK_PIDFILE"
  fi
}

start_ngrok_for_n8n() {
  local ngrok_bin="${N8N_NGROK_BIN:-ngrok}"
  local port="${N8N_NGROK_PORT:-${N8N_PORT:-5678}}"
  local ngrok_log=".ngrok-n8n.log"

  stop_ngrok_for_n8n

  if ! command -v "$ngrok_bin" >/dev/null 2>&1; then
    echo -e "${RED}❌ No se encontró '${ngrok_bin}'. Instalalo o ajustá N8N_NGROK_BIN en .env.${RESET}"
    return 0
  fi

  local domain_arg=()
  if [ -n "${N8N_NGROK_DOMAIN:-}" ]; then
    domain_arg=(--domain="${N8N_NGROK_DOMAIN}")
    echo -e "${YELLOW}🔗 Iniciando ngrok con dominio fijo: ${N8N_NGROK_DOMAIN}${RESET}"
  else
    echo -e "${YELLOW}🔗 Iniciando ngrok con subdominio dinámico (free).${RESET}"
  fi

  # Logeamos a archivo para diagnosticar rate-limit/errores
  nohup "$ngrok_bin" http "${domain_arg[@]}" "${port}" --log=stdout >"${ngrok_log}" 2>&1 &
  echo $! > "$NGROK_PIDFILE"
  echo -e "${GREEN}✅ ngrok iniciado (PID $(cat "$NGROK_PIDFILE")). Log: ${ngrok_log}${RESET}"

  # Espera corta por la API local (4040). Si no aparece, seguimos igual.
  local max_attempts=12 sleep_time=1 ok_api=0
  for i in $(seq 1 $max_attempts); do
    if curl -sf http://127.0.0.1:4040/api/tunnels >/dev/null 2>&1; then
      ok_api=1
      break
    fi
    sleep $sleep_time
  done

  if [ "$ok_api" -eq 1 ]; then
    # Primer HTTPS public_url
    local public_url domain
    public_url="$(curl -sf http://127.0.0.1:4040/api/tunnels | grep -o '"public_url":"https:[^"]*"' | head -n1 | sed 's/"public_url":"\(.*\)"/\1/')"
    if [ -n "$public_url" ]; then
      domain="$(echo "$public_url" | sed -E 's#https?://([^/]+).*#\1#')"
      # Exportamos para que n8n construya bien los callbacks OAuth
      export N8N_WEBHOOK_URL="$public_url"
      export N8N_HOST="$domain"
      export N8N_PROTOCOL="https"
      export N8N_PORT="443"
      echo -e "${GREEN}🌐 ngrok URL:${RESET} ${CYAN}${public_url}${RESET}"
      echo -e "${YELLOW}↪ Exportadas para esta sesión:${RESET}"
      echo -e "   N8N_WEBHOOK_URL=${N8N_WEBHOOK_URL}"
      echo -e "   N8N_HOST=${N8N_HOST}"
      echo -e "   N8N_PROTOCOL=${N8N_PROTOCOL}"
      echo -e "   N8N_PORT=${N8N_PORT}"
    else
      echo -e "${YELLOW}⚠️ ngrok corriendo, pero aún no publica URL. Seguimos. Revisá ${ngrok_log} o http://127.0.0.1:4040${RESET}"
    fi
  else
    echo -e "${YELLOW}⚠️ No respondió la API de ngrok (4040) a tiempo. Seguimos. Log: ${ngrok_log}${RESET}"
  fi
}

# ==========================================================
# 🧪 INFO ÚTIL (OAuth y URL pública)
# ==========================================================
print_n8n_oauth_info() {
  local base="${N8N_WEBHOOK_URL:-https://localhost:${N8N_PORT:-5678}}"
  base="${base%/}"
  local redirect="${base}/rest/oauth2-credential/callback"
  local origin
  origin="$(echo "$base" | sed -E 's#(https?://[^/]+).*#\1#')"

  echo -e "\n${CYAN}${BOLD}🔑 OAuth (n8n) – Pegá en Google Cloud:${RESET}"
  echo -e "   • Authorized redirect URIs:        ${GREEN}${redirect}${RESET}"
  echo -e "   • Authorized JavaScript origins:   ${GREEN}${origin}${RESET}\n"
}

print_ngrok_public_url() {
  local base="${N8N_WEBHOOK_URL:-}"
  if [ -z "$base" ] && [ -n "${N8N_HOST:-}" ] && [ -n "${N8N_PROTOCOL:-}" ]; then
    base="${N8N_PROTOCOL}://${N8N_HOST}"
  fi
  [ -z "$base" ] && return 0
  base="${base%/}"
  echo -e "${CYAN}${BOLD}🌍 n8n (externo via ngrok):${RESET} ${GREEN}${base}${RESET}  ${YELLOW}(BasicAuth ${N8N_BASIC_AUTH_USER:-admin}/${N8N_BASIC_AUTH_PASSWORD:-admin})${RESET}"
}

# ==========================================================
# ✅ CHEQUEOS DE SERVICIOS (DB/Airflow)
# ==========================================================
check_mariadb() {
  echo -e "${YELLOW}🔍 Verificando conexión a MariaDB...${RESET}"
  if docker exec mariadb mariadb -u"${MARIADB_USER}" -p"${MARIADB_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ MariaDB responde correctamente.${RESET}"
  else
    echo -e "${RED}❌ Error al conectar con MariaDB.${RESET}"
  fi
}

check_airflow_db_init() {
  echo -e "${YELLOW}🧠 Verificando inicialización de base Airflow...${RESET}"
  if ! docker exec airflow-webserver airflow db check-migrations >/dev/null 2>&1; then
    echo -e "${YELLOW}🧩 Ejecutando airflow db init (primera vez)...${RESET}"
    docker exec airflow-webserver airflow db init >/dev/null 2>&1 \
      && echo -e "${GREEN}✅ Base de datos Airflow inicializada.${RESET}" \
      || echo -e "${RED}❌ Error inicializando la base de Airflow.${RESET}"
  else
    echo -e "${GREEN}✅ Base de datos Airflow ya inicializada.${RESET}"
  fi
}

ensure_airflow_connection() {
  echo -e "${YELLOW}🔗 Creando conexión 'spark_default' en Airflow (si no existe)...${RESET}"
  if docker exec airflow-webserver airflow connections get spark_default >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Conexión 'spark_default' ya existe.${RESET}"
  else
    docker exec airflow-webserver bash -lc "airflow connections add spark_default --conn-uri 'spark://spark-master:7077'" >/dev/null 2>&1 \
      && echo -e "${GREEN}✅ Conexión 'spark_default' creada.${RESET}" \
      || echo -e "${RED}❌ No se pudo crear 'spark_default'. Revisá logs del webserver.${RESET}"
  fi
}

# ==========================================================
# 🚀 INICIAR ENTORNO BIG DATA
# ==========================================================
start_services() {
  echo -e "${CYAN}${BOLD}🚀 Iniciando entorno Big Data completo...${RESET}"
  fix_volumes

  # Iniciar ngrok ANTES de levantar n8n
  start_ngrok_for_n8n

  COMPOSE_PROJECT_NAME="${BIGDATA_PROJECT_NAME}" docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --build

  wait_for_service mariadb "MariaDB"
  check_mariadb

  wait_for_service spark-master "Spark Master"
  wait_for_service superset "Superset"
  wait_for_service jupyterlab "JupyterLab"

  AIRFLOW_HTTP_PORT="${AIRFLOW_PORT:-8090}"
  wait_for_http "${AIRFLOW_HTTP_PORT}" "/health" "Airflow Webserver"
  wait_for_flower

  wait_for_n8n

  check_airflow_db_init
  ensure_airflow_connection

  # Mostrar URIs para configurar OAuth en Google
  print_n8n_oauth_info

  # Mostrar URL pública de n8n (ngrok) con credenciales
  print_ngrok_public_url

  echo -e "\n${GREEN}✅ Todos los servicios Big Data principales están listos y verificados.${RESET}\n"

  echo -e "${CYAN}${BOLD}🌐 SERVICIOS BIG DATA:${RESET}"
  echo -e "➡️  ${BOLD}MariaDB (Adminer):${RESET} ${GREEN}http://localhost:8089${RESET}   ${YELLOW}(user:${MARIADB_USER} / pass:${MARIADB_PASSWORD})${RESET}"
  echo -e "➡️  ${BOLD}MinIO Console:${RESET}  ${GREEN}http://localhost:${MINIO_CONSOLE_PORT}${RESET}   ${YELLOW}(user:${MINIO_ROOT_USER} / pass:${MINIO_ROOT_PASSWORD})${RESET}"
  echo -e "➡️  ${BOLD}Spark Master:${RESET}   ${GREEN}http://localhost:${SPARK_MASTER_WEBUI_PORT}${RESET}"
  echo -e "➡️  ${BOLD}Spark History:${RESET}  ${GREEN}http://localhost:${SPARK_HISTORY_PORT}${RESET}"
  echo -e "➡️  ${BOLD}Airflow Web:${RESET}    ${GREEN}http://localhost:${AIRFLOW_HTTP_PORT}${RESET}   ${YELLOW}(user:${AIRFLOW_ADMIN_USER} / pass:${AIRFLOW_ADMIN_PASS})${RESET}"
  echo -e "➡️  ${BOLD}Flower UI:${RESET}      ${GREEN}http://localhost:5555${RESET}"
  echo -e "➡️  ${BOLD}Superset:${RESET}       ${GREEN}http://localhost:${SUPERSET_PORT}${RESET}   ${YELLOW}(user:${SUPERSET_ADMIN_USER} / pass:${SUPERSET_ADMIN_PASSWORD})${RESET}"
  echo -e "➡️  ${BOLD}JupyterLab:${RESET}     ${GREEN}http://localhost:${JUPYTER_PORT}${RESET}   ${YELLOW}(token:${JUPYTER_TOKEN})${RESET}"
  echo -e "➡️  ${BOLD}n8n (local):${RESET}     ${GREEN}http://localhost:${N8N_PORT}${RESET}   ${YELLOW}(user:${N8N_BASIC_AUTH_USER} / pass:${N8N_BASIC_AUTH_PASSWORD})${RESET}"

  if [ -n "${N8N_WEBHOOK_URL:-}" ]; then
    N8N_PUBLIC_URL="${N8N_WEBHOOK_URL%/}"
    echo -e "➡️  ${BOLD}n8n (público/ngrok):${RESET} ${GREEN}${N8N_PUBLIC_URL}${RESET}   ${YELLOW}(user:${N8N_BASIC_AUTH_USER} / pass:${N8N_BASIC_AUTH_PASSWORD})${RESET}"
  elif [ -n "${N8N_NGROK_DOMAIN:-}" ]; then
    echo -e "➡️  ${BOLD}n8n (público/ngrok):${RESET} ${GREEN}https://${N8N_NGROK_DOMAIN}${RESET}   ${YELLOW}(user:${N8N_BASIC_AUTH_USER} / pass:${N8N_BASIC_AUTH_PASSWORD})${RESET}"
  else
    echo -e "➡️  ${BOLD}n8n (público/ngrok):${RESET} ${YELLOW}(dominio dinámico; ver dashboard de ngrok en http://127.0.0.1:4040)${RESET}"
  fi
}

# ==========================================================
# 🚀 INICIAR ENTORNO MECABIOS (INFRA PRODUCCIÓN)
# ==========================================================
start_mechabios_services() {
  if [ ! -f "$MECHABIOS_COMPOSE_FILE" ]; then
    echo -e "${RED}❌ No se encontró $MECHABIOS_COMPOSE_FILE. Abortando.${RESET}"
    exit 1
  fi

  echo -e "${CYAN}${BOLD}🚀 Iniciando infraestructura Mechabios (producción)...${RESET}"
  COMPOSE_PROJECT_NAME="${MECHABIOS_PROJECT_NAME}" docker compose --env-file "$ENV_FILE" -f "$MECHABIOS_COMPOSE_FILE" up -d --build

  echo -e "${GREEN}✅ Infraestructura Mechabios levantada (ver docker compose ps -p ${MECHABIOS_PROJECT_NAME}).${RESET}"
}

# ==========================================================
# 🚀 INICIAR TODO (MECABIOS + BIG DATA)
# ==========================================================
start_all_services() {
  # Primero infra de producción, luego stack Big Data
  start_mechabios_services
  start_services
}

# ==========================================================
# 🛑 DETENER ENTORNO BIG DATA
# ==========================================================
stop_services() {
  echo -e "${YELLOW}🛑 Deteniendo contenedores Big Data...${RESET}"
  COMPOSE_PROJECT_NAME="${BIGDATA_PROJECT_NAME}" docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down
  stop_ngrok_for_n8n
  echo -e "${GREEN}✅ Entorno Big Data detenido correctamente.${RESET}"
}

# ==========================================================
# 🛑 DETENER ENTORNO MECABIOS
# ==========================================================
stop_mechabios_services() {
  if [ ! -f "$MECHABIOS_COMPOSE_FILE" ]; then
    echo -e "${RED}❌ No se encontró $MECHABIOS_COMPOSE_FILE. Nada que detener.${RESET}"
    return 0
  fi

  echo -e "${YELLOW}🛑 Deteniendo contenedores Mechabios...${RESET}"
  COMPOSE_PROJECT_NAME="${MECHABIOS_PROJECT_NAME}" docker compose --env-file "$ENV_FILE" -f "$MECHABIOS_COMPOSE_FILE" down
  echo -e "${GREEN}✅ Infraestructura Mechabios detenida correctamente.${RESET}"
}

# ==========================================================
# 🛑 DETENER TODO
# ==========================================================
stop_all_services() {
  stop_services
  stop_mechabios_services
}

# ==========================================================
# 📊 ESTADO ACTUAL BIG DATA
# ==========================================================
status_services() {
  echo -e "${YELLOW}📊 Estado actual de contenedores Big Data:${RESET}"
  COMPOSE_PROJECT_NAME="${BIGDATA_PROJECT_NAME}" docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps
}

# ==========================================================
# 📊 ESTADO ACTUAL MECABIOS
# ==========================================================
status_mechabios_services() {
  if [ ! -f "$MECHABIOS_COMPOSE_FILE" ]; then
    echo -e "${RED}❌ No se encontró $MECHABIOS_COMPOSE_FILE.${RESET}"
    return 0
  fi

  echo -e "${YELLOW}📊 Estado actual de contenedores Mechabios:${RESET}"
  COMPOSE_PROJECT_NAME="${MECHABIOS_PROJECT_NAME}" docker compose --env-file "$ENV_FILE" -f "$MECHABIOS_COMPOSE_FILE" ps
}

# ==========================================================
# 📊 ESTADO GLOBAL
# ==========================================================
status_all_services() {
  status_mechabios_services
  status_services
}

# ==========================================================
# 🧹 LIMPIEZA PARCIAL
# ==========================================================
clean() {
  echo -e "${YELLOW}🧹 Limpiando logs de Airflow y eventos de Spark...${RESET}"
  rm -rf volumenes/airflow-logs/* volumenes/shared/spark-events/* 2>/dev/null || true
  echo -e "${GREEN}✅ Limpieza parcial completada.${RESET}"
}

# ==========================================================
# 💣 LIMPIEZA TOTAL
# ==========================================================
full_clean() {
  echo -e "${RED}${BOLD}⚠️  ESTA ACCIÓN ELIMINA TODO:${RESET}"
  echo -e "   - Contenedores, volúmenes e imágenes locales"
  echo -e "   - Carpeta ./volumenes"
  read -p "¿Continuar? (escribe 'SI' para confirmar): " confirm
  [ "$confirm" != "SI" ] && echo -e "${YELLOW}❌ Cancelado.${RESET}" && exit 0
  COMPOSE_PROJECT_NAME="${BIGDATA_PROJECT_NAME}" docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down --remove-orphans || true
  if [ -f "$MECHABIOS_COMPOSE_FILE" ]; then
    COMPOSE_PROJECT_NAME="${MECHABIOS_PROJECT_NAME}" docker compose --env-file "$ENV_FILE" -f "$MECHABIOS_COMPOSE_FILE" down --remove-orphans || true
  fi
  docker volume prune --all --force || true
  docker rmi -f $(docker images -q) 2>/dev/null || true
  sudo rm -rf ./volumenes || true
  stop_ngrok_for_n8n
  echo -e "${GREEN}✅ Limpieza total completada.${RESET}"
}

# ==========================================================
# MENU PRINCIPAL
# ==========================================================
case "${1:-}" in
  up) start_services ;;
  down) stop_services ;;
  status) status_services ;;
  up-infra) start_mechabios_services ;;
  down-infra) stop_mechabios_services ;;
  status-infra) status_mechabios_services ;;
  up-all) start_all_services ;;
  down-all) stop_all_services ;;
  status-all) status_all_services ;;
  clean) clean ;;
  full-clean) full_clean ;;
  *)
    echo -e "${YELLOW}Uso:${RESET} ./controller.sh {up|down|status|up-infra|down-infra|status-infra|up-all|down-all|status-all|clean|full-clean}"
    ;;
esac
