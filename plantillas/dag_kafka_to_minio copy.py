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
        docker exec spark-master /opt/spark/bin/spark-submit \
          --master spark://spark-master:7077 \
          --conf spark.eventLog.enabled=true \
          --conf spark.eventLog.dir=file:///tmp/spark-events \
          --conf spark.jars.ivy=/tmp/.ivy2 \
          --packages org.apache.spark:spark-sql-kafka-0-10_2.13:4.1.1,org.apache.hadoop:hadoop-aws:3.4.2,software.amazon.awssdk:bundle:2.23.19,org.wildfly.openssl:wildfly-openssl:1.1.3.Final \
          /opt/spark/app/spark_kafka_to_minio.py
        """,
    )