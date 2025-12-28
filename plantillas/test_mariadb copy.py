from pyspark.sql import SparkSession

# ==========================
# Parámetros de conexión
# ==========================
db_host = "mariadb"
db_port = "3306"
db_name = "airflow_db"      # usa la DB interna de airflow, garantizada
db_user = "bigdata_user"      # mismo usuario del .env
db_pass = "bigdata_pass"      # misma contraseña del .env
table_name = "information_schema.tables"

# ==========================
# Inicializar SparkSession
# ==========================
spark = SparkSession.builder \
    .appName("TestMariaDB") \
    .config("spark.jars", "/opt/spark/jars/mariadb-java-client.jar") \
    .getOrCreate()

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
