# ==============================
# Superset config para MariaDB
# ==============================

import os

# --- Clave secreta ---
SECRET_KEY = os.getenv("SUPERSET_SECRET_KEY", "changeme")

# --- Conexión a MariaDB (usa PyMySQL para máxima compatibilidad) ---
SQLALCHEMY_DATABASE_URI = (
    f"mysql+pymysql://{os.getenv('SUPERSET_DB_USER')}:{os.getenv('SUPERSET_DB_PASS')}"
    f"@{os.getenv('SUPERSET_DB_HOST')}:{os.getenv('SUPERSET_DB_PORT')}/{os.getenv('SUPERSET_DB_NAME')}"
)

# --- Configuración general ---
SQLALCHEMY_TRACK_MODIFICATIONS = False
WTF_CSRF_ENABLED = True
FEATURE_FLAGS = {"EMBEDDED_SUPERSET": True}

# --- Logs y directorios ---
DATA_DIR = os.getenv("SUPERSET_HOME", "/app/superset_home")
LOG_FOLDER = os.path.join(DATA_DIR, "logs")
os.makedirs(LOG_FOLDER, exist_ok=True)

# --- Seguridad ---
FAB_ADD_SECURITY_VIEWS = True
ENABLE_PROXY_FIX = True
