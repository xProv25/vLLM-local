<#
.SYNOPSIS
    Apre la Web Chat UI locale per interagire direttamente con vLLM.

.DESCRIPTION
    Apre il file scripts/chat_ui.html nel browser web predefinito di sistema.
    L'interfaccia si connette direttamente alle API vLLM su http://localhost:8000/v1
    mostrando i modelli attivi, token streaming, velocita di inferenza e parametri.

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
Write-Host "Apertura nel browser predefinito: $HtmlPath" -ForegroundColor Yellow
Write-Host ""

Start-Process $HtmlPath
