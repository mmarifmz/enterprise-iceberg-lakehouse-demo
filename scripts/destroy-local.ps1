[CmdletBinding(SupportsShouldProcess)]
param([string]$ClusterName = "iceberg-demo")

$ErrorActionPreference = "Stop"
if ($PSCmdlet.ShouldProcess("kind cluster '$ClusterName'", "Delete")) {
    kind delete cluster --name $ClusterName
}

