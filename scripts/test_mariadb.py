from pyspark.sql import SparkSession
from pyspark.sql.utils import AnalysisException

# ==============================
# 🔧 CONFIGURACIÓN DE CONEXIÓN
# ==============================
DB_HOST = "mariadb"
DB_PORT = "3306"
DB_NAME = "bigdata_db"
DB_USER = "bigdata_user"
DB_PASS = "bigdata_pass"
TABLE_NAME = "sensores"

# URL JDBC — usamos mysql:// + permitMysqlScheme para compatibilidad
url = (
    f"jdbc:mysql://{DB_HOST}:{DB_PORT}/{DB_NAME}"
    "?allowPublicKeyRetrieval=true"
    "&useSSL=false"
    "&permitMysqlScheme"
)

# ==============================
# 🚀 INICIAR SESIÓN SPARK
# ==============================
spark = (
    SparkSession.builder
    .appName("TestMariaDB_Stable")
    .config("spark.jars", "/opt/spark/jars/mariadb-java-client.jar")
    .getOrCreate()
)

print("🔌 Intentando conectar a MariaDB...")
print(f"   → URL: {url}")
print(f"   → Tabla: {TABLE_NAME}")

# ==============================
# 📥 LECTURA DESDE MARIADB
# ==============================
try:
    df = (
        spark.read.format("jdbc")
        .option("url", url)
        .option("dbtable", TABLE_NAME)
        .option("user", DB_USER)
        .option("password", DB_PASS)
        .option("driver", "org.mariadb.jdbc.Driver")
        .option("fetchsize", "1000")  # mejora rendimiento para tablas grandes
        .load()
    )

    print("\n✅ Conexión exitosa. Mostrando los primeros registros:\n")
    df.show()
    print("\n📊 Esquema de la tabla:")
    df.printSchema()
    print(f"\n📈 Total de filas: {df.count()}")

except AnalysisException as e:
    print(f"⚠️ Error de análisis Spark: {e}")
except Exception as e:
    print(f"❌ Error general al conectar o leer datos: {e}")
finally:
    spark.stop()
    print("\n🧹 Sesión Spark finalizada correctamente.")
