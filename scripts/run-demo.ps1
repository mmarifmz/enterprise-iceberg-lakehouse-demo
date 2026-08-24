[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
kubectl -n lakehouse wait --for=condition=available deployment/minio deployment/iceberg-rest deployment/trino --timeout=10m
kubectl -n lakehouse delete job adventureworks-ingest --ignore-not-found
kubectl -n lakehouse apply -f (Join-Path (Split-Path -Parent $PSScriptRoot) "deploy/kubernetes/ingest-job.yaml")
kubectl -n lakehouse wait --for=condition=complete job/adventureworks-ingest --timeout=20m
kubectl -n lakehouse logs job/adventureworks-ingest
kubectl -n lakehouse exec deployment/trino -- trino --execute "SELECT count(*) AS internet_sales_rows FROM iceberg.demo.fact_internet_sales"

