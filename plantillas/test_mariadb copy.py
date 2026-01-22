from pyspark.sql import SparkSession
import os
from pathlib import Path
from dotenv import load_dotenv

# ====
# 📁 CARGAR VARIABLES DEL .env (un nivel superior)
# ====
current_dir = Path(__file__).resolve().parent
parent_dir = current_dir.parent
env_path = parent_dir / ".env"

load_dotenv(dotenv_path=env_path)
print(f"🔍 Cargando variables desde: {env_path}")

# ====
# Parámetros de conexión (por env)
# Defaults iguales al archivo original.
# ====
db_host = os.environ.get("DB_HOST", "mariadb")
db_port = os.environ.get("DB_PORT", "3306")
db_name = os.environ.get("DB_NAME", "airflow_db")      # usa la DB interna de airflow, garantizada
db_user = os.environ.get("DB_USER", "bigdata_user")    # mismo usuario del .env
db_pass = os.environ.get("DB_PASS", "bigdata_pass")    # misma contraseña del .env
table_name = os.environ.get("DB_TABLE", "information_schema.tables")

JDBC_JAR = os.environ.get("JDBC_JAR", "/opt/spark/jars/mariadb-java-client.jar")
SPARK_APP_NAME = os.environ.get("SPARK_APP_NAME", "TestMariaDB")
SPARK_SESSION_TZ = os.environ.get("SPARK_SESSION_TZ", "UTC")

# ====
# Inicializar SparkSession
# ====
spark = SparkSession.builder \
    .appName(SPARK_APP_NAME) \
    .config("spark.jars", JDBC_JAR) \
    .getOrCreate()

spark.sql(f"SET spark.sql.session.timeZone={SPARK_SESSION_TZ}")

print("🚀 Iniciando conexión a MariaDB desde Spark...")

try:
    # Leer tabla desde MariaDB
    df = spark.read.format("jdbc") \
        .option("url", f"jdbc:mariadb://{db_host}:{db_port}/{db_name}") \
        .option("query", """
        SELECT
            CAST(TABLE_SCHEMA AS CHAR) AS TABLE_SCHEMA,
            CAST(TABLE_NAME   AS CHAR) AS TABLE_NAME
        FROM information_schema.tables
        LIMIT 20
        """) \
        .option("user", db_user) \
        .option("password", db_pass) \
        .option("driver", "org.mariadb.jdbc.Driver") \
        .load()

    # Mostrar resultados
    print("✅ Datos obtenidos:")
    df.show(5, truncate=False)

    count = df.count()
    print(f"📊 Total de filas en {table_name}: {count}")

except Exception as e:
    print(f"❌ Error al conectar o consultar: {e}")

finally:
    spark.stop()
    print("🏁 Script finalizado correctamente.")