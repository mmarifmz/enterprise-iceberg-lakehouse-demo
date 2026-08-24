[CmdletBinding()]
param([string]$ClusterName = "iceberg-demo")

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

foreach ($command in @("docker", "kubectl", "kind", "helm")) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Missing prerequisite '$command'. See README.md before deploying."
    }
}

$envPath = Join-Path $repoRoot ".env"
if (-not (Test-Path -LiteralPath $envPath)) {
    throw "Create .env from .env.example and set local-only values first."
}

Get-Content -LiteralPath $envPath | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
    }
}

foreach ($name in @("AIRFLOW_METADATA_URL", "MINIO_ROOT_USER", "MINIO_ROOT_PASSWORD", "AIRFLOW_ADMIN_PASSWORD")) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name, "Process")) -or
        [Environment]::GetEnvironmentVariable($name, "Process") -like "*replace*") {
        throw "Set $name to a real local value in .env."
    }
}

if (-not (kind get clusters | Select-String -SimpleMatch $ClusterName -Quiet)) {
    kind create cluster --name $ClusterName --config (Join-Path $repoRoot "deploy/kind/cluster.yaml")
}

docker build --tag enterprise-iceberg-demo/spark:local --file (Join-Path $repoRoot "images/spark/Dockerfile") $repoRoot
kind load docker-image enterprise-iceberg-demo/spark:local --name $ClusterName

kubectl create namespace lakehouse --dry-run=client -o yaml | kubectl apply -f -
kubectl -n lakehouse create secret generic lakehouse-secrets `
    --from-literal=minio-root-user=$env:MINIO_ROOT_USER `
    --from-literal=minio-root-password=$env:MINIO_ROOT_PASSWORD `
    --dry-run=client -o yaml | kubectl apply -f -
kubectl -n lakehouse create secret generic airflow-metadata `
    --from-literal=connection=$env:AIRFLOW_METADATA_URL `
    --dry-run=client -o yaml | kubectl apply -f -
kubectl -n lakehouse create configmap demo-dags `
    --from-file=(Join-Path $repoRoot "dags/adventureworks_lakehouse.py") `
    --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f (Join-Path $repoRoot "deploy/kubernetes/lakehouse.yaml")

helm repo add apache-airflow https://airflow.apache.org --force-update
helm repo update
helm upgrade --install airflow apache-airflow/airflow `
    --namespace lakehouse `
    --version 1.22.0 `
    --values (Join-Path $repoRoot "deploy/airflow/values.yaml") `
    --set-string createUserJob.defaultUser.password=$env:AIRFLOW_ADMIN_PASSWORD `
    --wait --timeout 15m

Write-Host "Lakehouse deployment submitted. Run ./scripts/run-demo.ps1 after pods are ready."
