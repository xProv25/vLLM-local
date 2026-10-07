<#
.SYNOPSIS
    Automates Static IP and Ethernet Interface configuration for Phase 2 Cluster.

.DESCRIPTION
    Configures static IP on Ethernet interface:
    - Head Node: 192.168.1.100 / 255.255.255.0
    - Worker Node: 192.168.1.101 / 255.255.255.0
    Optionally disables Wi-Fi to ensure 100% traffic traverses the dedicated Cat6 switch.

.EXAMPLE
    # Configure as Head Node
    .\scripts\setup_network.ps1 -Role Head

    # Configure as Worker Node
    .\scripts\setup_network.ps1 -Role Worker
#>
param(
    [ValidateSet("Head", "Worker")]
    [string]$Role = "Head",

    [string]$EthernetAlias = "Ethernet",

    [switch]$DisableWifi = $false
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "This script requires Administrator privileges to configure IP addresses."
    Write-Host "Please open PowerShell as Administrator and run:" -ForegroundColor Yellow
    Write-Host "  Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy Bypass -File .\scripts\setup_network.ps1 -Role $Role'" -ForegroundColor Cyan
    exit 1
}

$IpAddress = if ($Role -eq "Head") { "192.168.1.100" } else { "192.168.1.101" }
$SubnetMask = 24  # 255.255.255.0

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Configuring Static Network Interface ($Role Node)" -ForegroundColor Green
Write-Host " Target Interface:    $EthernetAlias" -ForegroundColor White
Write-Host " Target Static IP:    $IpAddress/24" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

# Check if Ethernet interface exists
$adapter = Get-NetAdapter -Name $EthernetAlias -ErrorAction SilentlyContinue
if (-not $adapter) {
    Write-Warning "Interface '$EthernetAlias' not found. Available adapters:"
    Get-NetAdapter | Format-Table Name, InterfaceDescription, Status -AutoSize
    exit 1
}

# Remove existing IP addresses on interface
Get-NetIPAddress -InterfaceAlias $EthernetAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue | `
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

# Assign static IP
New-NetIPAddress -InterfaceAlias $EthernetAlias -IPAddress $IpAddress -PrefixLength $SubnetMask -ErrorAction Stop | Out-Null
Write-Host "[OK] Assigned IP $IpAddress to $EthernetAlias" -ForegroundColor Green

if ($DisableWifi) {
    $wifi = Get-NetAdapter -Name "Wi-Fi" -ErrorAction SilentlyContinue
    if ($wifi -and $wifi.Status -ne "Disabled") {
        Disable-NetAdapter -Name "Wi-Fi" -Confirm:$false
        Write-Host "[OK] Wi-Fi adapter disabled to enforce Cat6 wired transmission." -ForegroundColor Yellow
    }
}

Write-Host "`n[SUCCESS] Network successfully configured for $Role Node!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
