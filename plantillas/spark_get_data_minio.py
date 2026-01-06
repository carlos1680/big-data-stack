import os
import io
import boto3
from botocore.client import Config

PREFIX = os.getenv("MINIO_PREFIX", "raw/kafka/test_topic/")
BUCKET = os.getenv("MINIO_BUCKET", "data")

s3 = boto3.client(
    "s3",
    endpoint_url=os.getenv("MINIO_ENDPOINT", "http://minio:9000"),
    aws_access_key_id=os.getenv("MINIO_ACCESS_KEY", "admin"),
    aws_secret_access_key=os.getenv("MINIO_SECRET_KEY", "admin123"),
    config=Config(signature_version="s3v4"),
    region_name=os.getenv("AWS_REGION", "us-east-1"),
)

print("\n" + "=" * 90)
print(f"📦 Listando objetos en bucket='{BUCKET}' prefix='{PREFIX}'")
print("=" * 90)

resp = s3.list_objects_v2(Bucket=BUCKET, Prefix=PREFIX)
contents = resp.get("Contents", [])
if not contents:
    print("⚠️  No se encontraron objetos con ese prefix.")
    print("=" * 90 + "\n")
    raise SystemExit(0)

for obj in contents:
    print(f"{obj['Key']}  {obj['Size']} bytes")

print("=" * 90)

# Buscar el primer parquet para previsualizar
parquet_key = None
for obj in contents:
    if obj["Key"].endswith(".parquet"):
        parquet_key = obj["Key"]
        break

if not parquet_key:
    print("⚠️  No encontré archivos .parquet para mostrar contenido.")
    print("=" * 90 + "\n")
    raise SystemExit(0)

print(f"📥 Descargando parquet para preview: {parquet_key}")

obj = s3.get_object(Bucket=BUCKET, Key=parquet_key)
data = obj["Body"].read()

# Leer parquet
import pyarrow.parquet as pq
import pandas as pd

table = pq.read_table(io.BytesIO(data))
df = table.to_pandas()

print("\n🧱 Schema (pandas dtypes):")
print(df.dtypes)

n = int(os.getenv("PREVIEW_ROWS", "20"))
print(f"\n📊 Preview primeras {n} filas:")
print(df.head(n).to_string(index=False))

print("\n✅ OK")
print("=" * 90 + "\n")