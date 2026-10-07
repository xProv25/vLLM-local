<#
.SYNOPSIS
    Quick test script for vLLM OpenAI API from Windows PowerShell.
#>
param(
    [string]$BaseUrl = "http://localhost:8000",
    [string]$ApiKey = "vllm-local-token",
    [string]$Model = ""
)

$headers = @{
    "Authorization" = "Bearer $ApiKey"
    "Content-Type" = "application/json"
}

Write-Host ">>> 1. Checking models list on $BaseUrl..." -ForegroundColor Cyan

# Wait loop for server readiness (max 60 seconds)
$maxRetries = 15
$models = $null

for ($i = 1; $i -le $maxRetries; $i++) {
    try {
        $models = Invoke-RestMethod -Uri "$BaseUrl/v1/models" -Headers $headers -Method Get -TimeoutSec 10
        if ($models -and $models.data) {
            break
        }
    } catch {
        Write-Host "    [*] Il server vLLM sta caricando il modello in GPU VRAM... (tentativo $i/$maxRetries)" -ForegroundColor DarkGray
        Start-Sleep -Seconds 3
    }
}

if (-not $models -or -not $models.data) {
    Write-Host "[-] Impossibile connettersi a $BaseUrl/v1/models." -ForegroundColor Red
    Write-Host "    Assicurati che nel Terminale 1 compaia il messaggio:" -ForegroundColor Yellow
    Write-Host "    'INFO: Uvicorn running on http://0.0.0.0:8000'" -ForegroundColor White
    exit 1
}

Write-Host "Available Models:" -ForegroundColor Green
$loadedModels = @($models.data | ForEach-Object { $_.id })
$loadedModels | ForEach-Object { Write-Host " - $_" -ForegroundColor Green }

# Auto-detect target model if not specified or not matching
$targetModel = $Model
if ([string]::IsNullOrWhiteSpace($targetModel) -or ($targetModel -notin $loadedModels)) {
    $targetModel = $loadedModels[0]
}

Write-Host "`n>>> 2. Testing Chat Completion with '$targetModel'..." -ForegroundColor Cyan
$body = @{
    model = $targetModel
    messages = @(
        @{ role = "system"; content = "Sei un assistente AI veloce e preciso." },
        @{ role = "user"; content = "Ciao! Sei operativo? Rispondi in una sola frase." }
    )
    max_tokens = 64
    temperature = 0.3
} | ConvertTo-Json -Depth 5

try {
    $res = Invoke-RestMethod -Uri "$BaseUrl/v1/chat/completions" -Headers $headers -Method Post -Body $body -TimeoutSec 30
    $reply = $res.choices[0].message.content
    Write-Host "Response received:" -ForegroundColor Green
    Write-Host $reply -ForegroundColor Yellow
} catch {
    Write-Host "[-] Request failed: $_" -ForegroundColor Red
}
