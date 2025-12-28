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

# URL JDBC (MariaDB) con flags recomendados
JDBC_URL = (
    f"jdbc:mysql://{DB_HOST}:{DB_PORT}/{DB_NAME}"
    "?useUnicode=true"
    "&permitMysqlScheme=true"
    "&characterEncoding=utf8"
    "&serverTimezone=UTC"
    "&tinyInt1isBit=false"
    "&zeroDateTimeBehavior=convertToNull"
)

# ==============================
# 🚀 INICIAR SESIÓN SPARK
# ==============================
spark = (
    SparkSession.builder
    .appName("TestMariaDB_Stable")
    # Asegurate de que este .jar esté presente en /opt/spark/jars
    .config("spark.jars", "/opt/spark/jars/mariadb-java-client.jar")
    .getOrCreate()
)

# Fijar zona horaria de la sesión para columnas TIMESTAMP
spark.sql("SET spark.sql.session.timeZone=UTC")

print("🔌 Intentando conectar a MariaDB...")
print(f"   → URL: {JDBC_URL}")
print(f"   → Tabla: {TABLE_NAME}")

# ==============================
# 📥 LECTURA DESDE MARIADB
# ==============================
try:
    df = (
        spark.read.format("jdbc")
        .option("url", JDBC_URL)
        .option("dbtable", TABLE_NAME)
        .option("user", DB_USER)
        .option("password", DB_PASS)
        .option("driver", "org.mariadb.jdbc.Driver")
        .option("fetchsize", "1000")   # tuning para tablas grandes
        .load()
    )

    print("\n✅ Conexión exitosa. Mostrando los primeros registros:\n")
    # Mostrar hasta 100 filas y sin truncar columnas
    df.show(100, truncate=False)

    print("\n📊 Esquema de la tabla:")
    df.printSchema()

    total = df.count()
    print(f"\n📈 Total de filas: {total}")

    # OPCIONAL: convertir a double para ciertos cálculos
    # df_num = df.selectExpr(
    #     "id",
    #     "dispositivo",
    #     "CAST(temperatura AS DOUBLE) AS temperatura",
    #     "CAST(humedad AS DOUBLE) AS humedad",
    #     "fecha"
    # )
    # df_num.printSchema()
    # df_num.show(100, truncate=False)

except AnalysisException as e:
    print(f"⚠️ Error de análisis Spark: {e}")
except Exception as e:
    print(f"❌ Error general al conectar o leer datos: {e}")
finally:
    spark.stop()
    print("\n🧹 Sesión Spark finalizada correctamente.")
