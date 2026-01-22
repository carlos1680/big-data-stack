from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator

# ======================================
# Configuración general del DAG
# ======================================
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 0,
    'retry_delay': timedelta(minutes=1),
}

dag = DAG(
    'dag_spark_pi',
    default_args=default_args,
    description='Ejemplo base: ejecutar SparkPi en el cluster',
    schedule_interval=None,
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['spark', 'test', 'example'],
)

# ======================================
# Tarea: ejecutar SparkPi
# ======================================
spark_pi = BashOperator(
    task_id='spark_pi_job',
    bash_command="""
        echo "🚀 Ejecutando SparkPi de prueba..."
        /opt/spark/bin/spark-submit \
            --master spark://spark-master:7077 \
            --class org.apache.spark.examples.SparkPi \
            /opt/spark/examples/jars/spark-examples_2.12-3.5.0.jar 100
        echo "✅ SparkPi completado."
    """,
    dag=dag,
)
