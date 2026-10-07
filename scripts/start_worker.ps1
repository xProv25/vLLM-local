<#
.SYNOPSIS
    Connects Worker Node to Ray Cluster from Windows PowerShell.
#>
param(
    [string]$HeadIp = "192.168.1.100",
    [string]$LocalIp = "192.168.1.101"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Starting Ray Cluster WORKER Node" -ForegroundColor Green
Write-Host " Head Address:     $HeadIp`:6379" -ForegroundColor White
Write-Host " Local Worker IP:  $LocalIp" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

$wslCmd = "export HEAD_IP=$HeadIp; export LOCAL_IP=$LocalIp; /mnt/c/Users/ADMIN/Desktop/vLLM/scripts/start_worker.sh"
wsl -d Ubuntu -e bash -c $wslCmd
