[CmdletBinding()]
param([string]$ClusterName = "iceberg-demo")

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
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
$existingSecret = kubectl -n lakehouse get secret lakehouse-secrets --ignore-not-found -o json | ConvertFrom-Json
$minioCredentialsChanged = $true
if ($existingSecret) {
    $existingUser = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($existingSecret.data.'minio-root-user'))
    $existingPassword = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($existingSecret.data.'minio-root-password'))
    $minioCredentialsChanged = $existingUser -ne $env:MINIO_ROOT_USER -or $existingPassword -ne $env:MINIO_ROOT_PASSWORD
}
kubectl -n lakehouse create secret generic lakehouse-secrets `
    --from-literal=minio-root-user=$env:MINIO_ROOT_USER `
    --from-literal=minio-root-password=$env:MINIO_ROOT_PASSWORD `
    --dry-run=client -o yaml | kubectl apply -f -
kubectl -n lakehouse create secret generic airflow-metadata `
    --from-literal=connection=$env:AIRFLOW_METADATA_URL `
    --dry-run=client -o yaml | kubectl apply -f -
$dagPath = Join-Path $repoRoot "dags/adventureworks_lakehouse.py"
kubectl -n lakehouse create configmap demo-dags `
    --from-file=$dagPath `
    --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f (Join-Path $repoRoot "deploy/kubernetes/lakehouse.yaml")

if ($minioCredentialsChanged -and (kubectl -n lakehouse get deployment minio --ignore-not-found -o name)) {
    Write-Host "MinIO credentials changed; restarting the disposable local data plane."
    kubectl -n lakehouse rollout restart deployment/minio deployment/iceberg-rest deployment/trino
    kubectl -n lakehouse rollout status deployment/minio --timeout=5m
    kubectl -n lakehouse rollout status deployment/iceberg-rest --timeout=5m
    kubectl -n lakehouse rollout status deployment/trino --timeout=5m
    kubectl -n lakehouse delete job minio-bootstrap --ignore-not-found
    kubectl apply -f (Join-Path $repoRoot "deploy/kubernetes/lakehouse.yaml")
    kubectl -n lakehouse wait --for=condition=complete job/minio-bootstrap --timeout=5m
}

helm repo add apache-airflow https://airflow.apache.org --force-update
helm repo update
helm upgrade --install airflow apache-airflow/airflow `
    --namespace lakehouse `
    --version 1.22.0 `
    --values (Join-Path $repoRoot "deploy/airflow/values.yaml") `
    --set-string createUserJob.defaultUser.password=$env:AIRFLOW_ADMIN_PASSWORD `
    --hide-notes `
    --timeout 15m

kubectl -n lakehouse rollout status deployment/airflow-api-server --timeout=10m
kubectl -n lakehouse rollout status deployment/airflow-dag-processor --timeout=10m
kubectl -n lakehouse rollout status statefulset/airflow-scheduler --timeout=10m
kubectl -n lakehouse rollout status statefulset/airflow-triggerer --timeout=10m
kubectl -n lakehouse exec deployment/airflow-api-server -c api-server -- `
    airflow users reset-password --username admin --password $env:AIRFLOW_ADMIN_PASSWORD | Out-Null

Write-Host "Lakehouse and Airflow are ready. Run ./scripts/run-demo.ps1 to load the sample data."
