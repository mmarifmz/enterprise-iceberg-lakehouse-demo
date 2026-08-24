[CmdletBinding()]
param([string]$Namespace = "lakehouse")

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
$repoRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $repoRoot ".env"

if (-not (Test-Path -LiteralPath $envPath)) {
    throw "Missing ignored .env file. Provision the local Airflow database first."
}

$newPassword = [Convert]::ToHexString(
    [Security.Cryptography.RandomNumberGenerator]::GetBytes(24)
).ToLowerInvariant()

$lines = Get-Content -LiteralPath $envPath
$found = $false
$updated = foreach ($line in $lines) {
    if ($line -match '^AIRFLOW_ADMIN_PASSWORD=') {
        $found = $true
        "AIRFLOW_ADMIN_PASSWORD=$newPassword"
    } else {
        $line
    }
}
if (-not $found) {
    $updated += "AIRFLOW_ADMIN_PASSWORD=$newPassword"
}

[IO.File]::WriteAllLines($envPath, $updated, [Text.UTF8Encoding]::new($false))
kubectl -n $Namespace exec deployment/airflow-api-server -c api-server -- `
    airflow users reset-password --username admin --password $newPassword | Out-Null

Write-Host "Rotated the local Airflow admin credential and updated the ignored .env file."
