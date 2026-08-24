[CmdletBinding()]
param([string]$ClusterName = "iceberg-demo")

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

foreach ($command in @("docker", "kubectl", "kind")) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Missing prerequisite '$command'. Open a new terminal after installing prerequisites."
    }
}

docker info --format '{{.ServerVersion}}' | Out-Null

if (-not (kind get clusters | Select-String -SimpleMatch $ClusterName -Quiet)) {
    kind create cluster `
        --name $ClusterName `
        --config (Join-Path $repoRoot "deploy/kind/cluster.yaml") `
        --wait 180s
}

kubectl create namespace lakehouse --dry-run=client -o yaml | kubectl apply -f -

if (-not (kubectl -n lakehouse get secret lakehouse-secrets --ignore-not-found -o name)) {
    $minioPassword = [Convert]::ToHexString(
        [Security.Cryptography.RandomNumberGenerator]::GetBytes(24)
    ).ToLowerInvariant()
    kubectl -n lakehouse create secret generic lakehouse-secrets `
        --from-literal=minio-root-user=lakehouse-demo `
        --from-literal=minio-root-password=$minioPassword | Out-Null
    Write-Host "Created an untracked Kubernetes Secret for MinIO."
}

docker build `
    --tag enterprise-iceberg-demo/spark:local `
    --file (Join-Path $repoRoot "images/spark/Dockerfile") `
    $repoRoot
kind load docker-image enterprise-iceberg-demo/spark:local --name $ClusterName

kubectl apply -f (Join-Path $repoRoot "deploy/kubernetes/lakehouse.yaml")
kubectl -n lakehouse wait `
    --for=condition=available `
    deployment/minio deployment/iceberg-rest deployment/trino `
    --timeout=10m
kubectl -n lakehouse wait --for=condition=complete job/minio-bootstrap --timeout=5m

Write-Host "Core lakehouse is ready. Run ./scripts/verify-core-local.ps1."

