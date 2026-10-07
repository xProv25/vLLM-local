<#
.SYNOPSIS
    Connects Worker Node to Ray Cluster from Windows PowerShell.
#>
param(
    [string]$HeadIp = "192.168.1.100",
    [string]$LocalIp = ""
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Starting Ray Cluster WORKER Node" -ForegroundColor Green
Write-Host " Head Address:     $HeadIp`:6379" -ForegroundColor White
if ($LocalIp) {
    Write-Host " Local Worker IP:  $LocalIp" -ForegroundColor White
} else {
    Write-Host " Local Worker IP:  Auto-detecting from active interface..." -ForegroundColor White
}
Write-Host "==========================================================" -ForegroundColor Cyan

$scriptDirWsl = (wsl -d Ubuntu -e wslpath -a -u ($PSScriptRoot -replace '\\', '/')).Trim()
$exportLocal = if ($LocalIp) { "export LOCAL_IP=$LocalIp;" } else { "" }
$wslCmd = "export HEAD_IP=$HeadIp; $exportLocal $scriptDirWsl/start_worker.sh"
wsl -d Ubuntu -e bash -c $wslCmd
