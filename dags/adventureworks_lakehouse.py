"""Airflow DAG for the Kubernetes-hosted AdventureWorks lakehouse demo."""

from __future__ import annotations

from datetime import UTC, datetime

from airflow import DAG
from airflow.kubernetes.secret import Secret
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator

MINIO_ACCESS_KEY = Secret("env", "AWS_ACCESS_KEY_ID", "lakehouse-secrets", "minio-root-user")
MINIO_SECRET_KEY = Secret(
    "env", "AWS_SECRET_ACCESS_KEY", "lakehouse-secrets", "minio-root-password"
)

with DAG(
    dag_id="adventureworks_lakehouse",
    description="Ingest AdventureWorksDW to Iceberg and expose it through Trino",
    start_date=datetime(2026, 1, 1, tzinfo=UTC),
    schedule=None,
    catchup=False,
    tags=["demo", "iceberg", "spark"],
) as dag:
    ingest = KubernetesPodOperator(
        task_id="spark_ingest",
        name="airflow-adventureworks-ingest",
        namespace="lakehouse",
        image="enterprise-iceberg-demo/spark:local",
        image_pull_policy="IfNotPresent",
        cmds=["/opt/spark/bin/spark-submit"],
        arguments=[
            "--master",
            "local[*]",
            "--packages",
            (
                "org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.10.0,"
                "org.apache.iceberg:iceberg-aws-bundle:1.10.0"
            ),
            "/opt/demo/jobs/ingest_adventureworks.py",
        ],
        env_vars={
            "ICEBERG_REST_URI": "http://iceberg-rest:8181",
            "S3_ENDPOINT": "http://minio:9000",
            "AWS_REGION": "us-east-1",
            "AWS_DEFAULT_REGION": "us-east-1",
        },
        secrets=[MINIO_ACCESS_KEY, MINIO_SECRET_KEY],
        get_logs=True,
        is_delete_operator_pod=True,
    )
