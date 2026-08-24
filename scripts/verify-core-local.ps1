[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$deployments = @("minio", "iceberg-rest", "trino")
foreach ($deployment in $deployments) {
    kubectl -n lakehouse wait `
        --for=condition=available `
        "deployment/$deployment" `
        --timeout=2m | Out-Null
}

$minioHealth = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:9000/minio/health/ready"
if ($minioHealth.StatusCode -ne 200) {
    throw "MinIO readiness endpoint returned $($minioHealth.StatusCode)."
}

$icebergConfig = Invoke-RestMethod -Uri "http://localhost:8181/v1/config"
if ($null -eq $icebergConfig) {
    throw "Iceberg REST catalog did not return configuration."
}

$trinoInfo = Invoke-RestMethod -Uri "http://localhost:8081/v1/info"
if ([string]::IsNullOrWhiteSpace($trinoInfo.nodeVersion.version)) {
    throw "Trino did not return a server version."
}

$sqlResult = kubectl -n lakehouse exec deployment/trino -- trino --output-format CSV --execute "SELECT 1 AS ready"
if (($sqlResult | Out-String) -notmatch "1") {
    throw "Trino SQL smoke query did not return 1."
}

kubectl -n lakehouse get pods -o wide
Write-Host "Verified MinIO, Iceberg REST, and Trino $($trinoInfo.nodeVersion.version)."

