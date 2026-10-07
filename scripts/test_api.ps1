<#
.SYNOPSIS
    Quick test script for vLLM OpenAI API from Windows PowerShell.
#>
param(
    [string]$BaseUrl = "http://localhost:8000",
    [string]$ApiKey = "vllm-local-token",
    [string]$Model = "Qwen/Qwen2.5-32B-Instruct-AWQ"
)

Write-Host ">>> 1. Checking models list..." -ForegroundColor Cyan
$headers = @{
    "Authorization" = "Bearer $ApiKey"
    "Content-Type" = "application/json"
}

try {
    $models = Invoke-RestMethod -Uri "$BaseUrl/v1/models" -Headers $headers -Method Get
    Write-Host "Available Models:" -ForegroundColor Green
    $models.data | ForEach-Object { Write-Host " - $($_.id)" }
} catch {
    Write-Host "[-] Failed to connect to $BaseUrl/v1/models : $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n>>> 2. Testing Chat Completion..." -ForegroundColor Cyan
$body = @{
    model = $Model
    messages = @(
        @{ role = "system"; content = "Sei un assistente AI veloce e preciso." },
        @{ role = "user"; content = "Ciao! Sei operativo? Rispondi in una sola frase." }
    )
    max_tokens = 64
    temperature = 0.3
} | ConvertTo-Json -Depth 5

try {
    $res = Invoke-RestMethod -Uri "$BaseUrl/v1/chat/completions" -Headers $headers -Method Post -Body $body
    $reply = $res.choices[0].message.content
    Write-Host "Response received:" -ForegroundColor Green
    Write-Host $reply -ForegroundColor Yellow
} catch {
    Write-Host "[-] Request failed: $_" -ForegroundColor Red
}
