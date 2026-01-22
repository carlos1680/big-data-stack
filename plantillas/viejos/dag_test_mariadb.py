from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 0,
    'retry_delay': timedelta(minutes=2),
}

with DAG(
    dag_id='dag_test_mariadb',
    default_args=default_args,
    description='DAG de prueba ejecutando Spark dentro del contenedor spark-master',
    schedule_interval=None,
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['spark', 'mariadb', 'test'],
) as dag:

    run_spark_job = BashOperator(
        task_id='spark_job_mariadb',
        bash_command="""
        echo "🚀 Ejecutando test_mariadb.py dentro de spark-master...";
        docker exec spark-master /opt/spark/bin/spark-submit \
          --master spark://spark-master:7077 \
          /opt/spark/app/test_mariadb.py
        """,
    )

    run_spark_job
