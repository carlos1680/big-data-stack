from pyspark.sql import SparkSession
from pyspark.sql.functions import col, from_json, to_timestamp
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType
import os
from pathlib import Path
from dotenv import load_dotenv

# Cargar .env (en tu caso, si el .env está en el repo/raíz, ajustá esta ruta si hace falta)
current_dir = Path(__file__).resolve().parent
parent_dir = current_dir.parent
env_path = parent_dir / ".env"
load_dotenv(dotenv_path=env_path)

KAFKA_BROKER = os.getenv("KAFKA_BROKER_ADDR", "kafka-broker:9092")
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "test_topic")

MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "http://minio:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", os.getenv("MINIO_ROOT_USER", "admin"))
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", os.getenv("MINIO_ROOT_PASSWORD", "admin123"))
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "data")
MINIO_PREFIX = os.getenv("MINIO_PREFIX", "raw/kafka/test_topic")

output_path = f"s3a://{MINIO_BUCKET}/{MINIO_PREFIX}/"

json_schema = StructType([
    StructField("id", IntegerType(), True),
    StructField("dispositivo", StringType(), True),
    StructField("temperatura", DoubleType(), True),
    StructField("humedad", DoubleType(), True),
    StructField("fecha", StringType(), True),
])

spark = (
    SparkSession.builder
    .appName("Kafka_to_MinIO")
    # S3A configs
    .config("spark.hadoop.fs.s3a.endpoint", MINIO_ENDPOINT)
    .config("spark.hadoop.fs.s3a.access.key", MINIO_ACCESS_KEY)
    .config("spark.hadoop.fs.s3a.secret.key", MINIO_SECRET_KEY)
    .config("spark.hadoop.fs.s3a.path.style.access", "true")
    .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false")  # endpoint http
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
    .getOrCreate()
)

try:
    df_kafka = (
        spark.read
        .format("kafka")
        .option("kafka.bootstrap.servers", KAFKA_BROKER)
        .option("subscribe", KAFKA_TOPIC)
        .option("startingOffsets", "earliest")
        .option("endingOffsets", "latest")
        .load()
    )

    df_raw = df_kafka.selectExpr("CAST(value AS STRING) as json_content")

    df_out = (
        df_raw
        .select(from_json(col("json_content"), json_schema).alias("data"))
        .select("data.*")
        .withColumn("fecha", to_timestamp(col("fecha"), "yyyy-MM-dd'T'HH:mm:ss"))
    )

    # Escribir a MinIO en Parquet (mejor para analytics)
    df_out.write.mode("append").parquet(output_path)

    print(f"✅ Escribí {df_out.count()} registros en {output_path}")

finally:
    spark.stop()