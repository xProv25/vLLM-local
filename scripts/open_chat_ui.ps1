<#
.SYNOPSIS
    Apre la Web Chat UI locale per interagire direttamente con vLLM.

.DESCRIPTION
    Apre il file scripts/chat_ui.html nel browser web predefinito di sistema.
    Avvia in background il micro-servizio Model Manager (porta 8001) per
    abilitare l'installazione e cancellazione modelli direttamente dalla GUI.

.EXAMPLE
    .\scripts\open_chat_ui.ps1
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$HtmlPath = Join-Path $ScriptDir "chat_ui.html"

if (-not (Test-Path $HtmlPath)) {
    Write-Error "File chat_ui.html non trovato in $HtmlPath."
    exit 1
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   AVVIO INTERFACCIA WEB CHAT vLLM (LOCALHOST:8000)      " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Verifica e avvio micro-servizio Model Manager su porta 8001
$Port8001Active = $false
try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $tcp.Connect("127.0.0.1", 8001)
    $tcp.Close()
    $Port8001Active = $true
} catch {}

if (-not $Port8001Active) {
    Write-Host "Avvio Model Manager Server (porta 8001)..." -ForegroundColor Yellow
    $ServerScript = Join-Path $ScriptDir "model_manager_server.py"
    Start-Process python -ArgumentList "`"$ServerScript`"" -WindowStyle Hidden
    Start-Sleep -Milliseconds 800
} else {
    Write-Host "Model Manager Server gia' attivo su porta 8001." -ForegroundColor Green
}

Write-Host "Apertura Web UI nel browser: $HtmlPath" -ForegroundColor Yellow
Write-Host ""

Start-Process $HtmlPath
