<#
.SYNOPSIS
    Downloads a GGUF model directly into LM Studio's local models library.

.DESCRIPTION
    Uses the LM Studio CLI (lms.exe) to fetch and install GGUF-quantized models
    optimized for NVIDIA RTX 4070 (8GB VRAM) so they appear in LM Studio's GUI.

.PARAMETER Model
    The model name or HuggingFace repo (default: "qwen2.5-7b-instruct").

.EXAMPLE
    .\scripts\install_lmstudio_model.ps1 -Model "qwen2.5-7b-instruct"
#>

[CmdletBinding()]
param(
    [string]$Model = "qwen2.5-7b-instruct"
)

$ErrorActionPreference = "Stop"

$LmsCli = "$HOME\.lmstudio\bin\lms.exe"
if (-not (Test-Path $LmsCli)) {
    Write-Error "LM Studio CLI (lms.exe) non trovato in $LmsCli. Assicurati che LM Studio sia installato correttamente."
    exit 1
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   LM STUDIO - DOWNLOAD & REGISTRAZIONE MODELLO GGUF      " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Modello target: $Model" -ForegroundColor Yellow
Write-Host "Directory destinazione: $HOME\.lmstudio\models" -ForegroundColor Gray
Write-Host ""

Write-Host "[1/2] Ricerca e download del modello ottimizzato GGUF per la GPU in corso..." -ForegroundColor Yellow
& $LmsCli get $Model --gguf -y

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[2/2] Download completato con successo!" -ForegroundColor Green
    Write-Host "Modelli attualmente registrati in LM Studio:" -ForegroundColor Cyan
    & $LmsCli ls
    Write-Host ""
    Write-Host "Il modello e' ora visibile e selezionabile all'interno di LM Studio GUI nella scheda Chat e My Models." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Errore durante il download del modello con lms CLI (Exit code: $LASTEXITCODE)." -ForegroundColor Red
    Write-Host "Puoi scaricarlo direttamente aprendo LM Studio -> Icona Ricerca -> Cerca '$Model' -> Download." -ForegroundColor Yellow
}
