<#
.SYNOPSIS
    Starts Ray Head Node (Master) from Windows PowerShell.
#>
param(
    [string]$HeadIp = "192.168.1.100",
    [int]$Port = 6379,
    [int]$DashboardPort = 8265
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Starting Ray Cluster HEAD Node (Master)" -ForegroundColor Green
Write-Host " IP Address:       $HeadIp" -ForegroundColor White
Write-Host " Ray Port:         $Port" -ForegroundColor White
Write-Host " Dashboard:        http://$HeadIp`:$DashboardPort" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

$scriptDirWsl = (wsl -d Ubuntu -e wslpath -a -u ($PSScriptRoot -replace '\\', '/')).Trim()
$wslCmd = "export HEAD_IP=$HeadIp; export RAY_PORT=$Port; export DASHBOARD_PORT=$DashboardPort; $scriptDirWsl/start_head.sh"
wsl -d Ubuntu -e bash -c $wslCmd
