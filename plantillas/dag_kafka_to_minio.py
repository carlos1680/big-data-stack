from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime

with DAG(
    dag_id="dag_kafka_to_minio_v1",
    start_date=datetime(2025, 1, 1),
    schedule_interval=None,
    catchup=False,
    tags=["spark", "kafka", "minio", "s3a"],
) as dag:

    spark_kafka_to_minio = BashOperator(
        task_id="spark_kafka_to_minio",
        bash_command="""
        set -e
        echo "🚀 Ejecutando Spark -> MinIO (S3A) ..."

        docker exec spark-master /opt/spark/bin/spark-submit \
          --master spark://spark-master:7077 \
          --conf spark.jars.ivy=/tmp/.ivy2 \
          --packages \
org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0,\
org.apache.hadoop:hadoop-aws:3.3.4,\
com.amazonaws:aws-java-sdk-bundle:1.12.262 \
          /opt/spark/app/spark_kafka_to_minio.py
        """,
    )