<#
.SYNOPSIS
    Configures Windows Firewall rules for vLLM & Ray Multi-Node Cluster (Phase 2).

.DESCRIPTION
    Opens required ports for:
    - Ray GCS Head: TCP 6379
    - Ray Dashboard: TCP 8265
    - Ray Worker communication: TCP 10000-10200
    - vLLM OpenAI API: TCP 8000
    - NCCL / Distributed PyTorch sockets: TCP 29500, TCP 30000-65535

    Must be executed with Administrator privileges.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\setup_firewall.ps1
#>

# Check for Administrator elevation
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "This script requires Administrator privileges to configure Windows Firewall."
    Write-Host "Please open PowerShell as Administrator and run:" -ForegroundColor Yellow
    Write-Host "  Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy Bypass -File .\scripts\setup_firewall.ps1'" -ForegroundColor Cyan
    exit 1
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Configuring Windows Firewall for vLLM & Ray Cluster" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan

$Rules = @(
    @{ Name = "vLLM-Ray-GCS"; Protocol = "TCP"; Port = "6379"; Desc = "Ray Head GCS Core Service" },
    @{ Name = "vLLM-Ray-Dashboard"; Protocol = "TCP"; Port = "8265"; Desc = "Ray Web Dashboard" },
    @{ Name = "vLLM-Ray-Workers"; Protocol = "TCP"; Port = "10000-10200"; Desc = "Ray Worker Node Ports" },
    @{ Name = "vLLM-API-Server"; Protocol = "TCP"; Port = "8000"; Desc = "vLLM OpenAI Compatible HTTP Server" },
    @{ Name = "vLLM-PyTorch-Rendezvous"; Protocol = "TCP"; Port = "29500"; Desc = "PyTorch Distributed Master Port" },
    @{ Name = "vLLM-NCCL-Sockets"; Protocol = "TCP"; Port = "30000-65535"; Desc = "NCCL High Port Dynamic Sockets" }
)

foreach ($r in $Rules) {
    Write-Host "[+] Configuring $($r.Name) ($($r.Protocol) $($r.Port))..." -ForegroundColor Gray
    
    # Remove existing rule if present
    Remove-NetFirewallRule -DisplayName $r.Name -ErrorAction SilentlyContinue

    # Add Inbound rule
    New-NetFirewallRule -DisplayName $r.Name `
        -Description $r.Desc `
        -Direction Inbound `
        -LocalPort $r.Port `
        -Protocol $r.Protocol `
        -Action Allow `
        -Profile Any `
        -Enabled True | Out-Null

    # Add Outbound rule
    New-NetFirewallRule -DisplayName "$($r.Name)-Outbound" `
        -Description "$($r.Desc) (Outbound)" `
        -Direction Outbound `
        -LocalPort $r.Port `
        -Protocol $r.Protocol `
        -Action Allow `
        -Profile Any `
        -Enabled True | Out-Null
        
    Write-Host "    [OK] Inbound & Outbound rules created for $($r.Port)" -ForegroundColor Green
}

Write-Host "`n[SUCCESS] Windows Firewall successfully configured for distributed Ray/vLLM!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
