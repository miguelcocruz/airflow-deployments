from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime
from pathlib import Path

import boto3


dag = DAG(
    dag_id="import_data_to_s3",
    schedule_interval="@daily",
    start_date=datetime(2023, 1, 15)
)


def _create_file():
    Path('test.txt').write_text('ahahah')


def _import_file_to_s3(filepath: str, bucket_name, object_name):
    s3 = boto3.client()
    with open(filepath, "rb") as file:
        s3.upload_fileobj(file, bucket_name, object_name)


create_file = PythonOperator(
    task_id="create_file",
    python_callable=_create_file,
    dag=dag
)

import_file_to_s3 = PythonOperator(
    task_id="import_file_to_s3",
    python_callable=_import_file_to_s3,
    op_kwargs={
        'filepath': 'test.txt',
        'bucket_name': 'mglvlm-20230121',
        'object_name': 'MyObject.txt'
    },
    dag=dag
)

_ = create_file >> import_file_to_s3