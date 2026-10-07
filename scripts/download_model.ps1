<#
.SYNOPSIS
    Scarica e installa automaticamente modelli LLM nella cache di vLLM (WSL2).

.DESCRIPTION
    Script di gestione e download automatico di modelli HuggingFace (AWQ/Safetensors)
    ottimizzati per la GPU NVIDIA RTX 4070 (8GB VRAM) o per il Cluster a 2 nodi (16GB VRAM).

.PARAMETER Model
    Identificativo del modello o alias:
    - 'qwen-7b'       -> Qwen/Qwen2.5-7B-Instruct-AWQ (Default, ~4.5 GB, 8GB VRAM)
    - 'deepseek-r1-7b'-> casperhansen/deepseek-r1-distill-qwen-7b-awq (~4.8 GB, 8GB VRAM)
    - 'llama-3.2-3b'  -> meta-llama/Llama-3.2-3B-Instruct (~2.5 GB, 8GB VRAM)
    - 'mistral-7b'    -> solidrust/Mistral-7B-Instruct-v0.3-AWQ (~4.5 GB, 8GB VRAM)
    - 'qwen-32b'      -> Qwen/Qwen2.5-32B-Instruct-AWQ (~18 GB, Richiede Cluster 2 PC 16GB)
    - oppure qualsiasi repository HuggingFace valido (es. "user/model-name").

.EXAMPLE
    .\scripts\download_model.ps1 -Model "deepseek-r1-7b"
    .\scripts\download_model.ps1 -Model "Qwen/Qwen2.5-7B-Instruct-AWQ"
#>

[CmdletBinding()]
param(
    [string]$Model = "qwen-7b",
    [string]$Distro = "Ubuntu"
)

$ErrorActionPreference = "Stop"

# Mappatura alias -> Repository HuggingFace reale
$ModelCatalog = @{
    "qwen-7b"        = @{ Repo = "Qwen/Qwen2.5-7B-Instruct-AWQ"; Vram = "8GB"; Desc = "Qwen 2.5 7B Instruct AWQ (Singolo PC)" }
    "deepseek-r1-7b" = @{ Repo = "casperhansen/deepseek-r1-distill-qwen-7b-awq"; Vram = "8GB"; Desc = "DeepSeek-R1 Distill 7B AWQ Reasoning (Singolo PC)" }
    "llama-3.2-3b"   = @{ Repo = "meta-llama/Llama-3.2-3B-Instruct"; Vram = "8GB"; Desc = "Llama 3.2 3B Instruct Ultra-Fast (Singolo PC)" }
    "mistral-7b"     = @{ Repo = "solidrust/Mistral-7B-Instruct-v0.3-AWQ"; Vram = "8GB"; Desc = "Mistral 7B Instruct v0.3 AWQ (Singolo PC)" }
    "qwen-32b"       = @{ Repo = "Qwen/Qwen2.5-32B-Instruct-AWQ"; Vram = "16GB (Cluster)"; Desc = "Qwen 2.5 32B Instruct AWQ (Cluster 2 Nodi)" }
}

$TargetRepo = $Model
$TargetDesc = "Modello personalizzato HuggingFace"
$TargetVram = "Verificare requisiti"

if ($ModelCatalog.ContainsKey($Model.ToLower())) {
    $item = $ModelCatalog[$Model.ToLower()]
    $TargetRepo = $item.Repo
    $TargetDesc = $item.Desc
    $TargetVram = $item.Vram
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   vLLM - PROCEDURA AUTOMATICA DOWNLOAD & INSTALLAZIONE   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Modello:    $TargetRepo" -ForegroundColor Yellow
Write-Host "Descrizione: $TargetDesc" -ForegroundColor Gray
Write-Host "VRAM Target: $TargetVram" -ForegroundColor Gray
Write-Host "Ambiente:    WSL2 ($Distro) -> /home/admin_ubuntu/vllm-env" -ForegroundColor Gray
Write-Host ""

# Controllo spazio disco Windows C:
$DriveC = Get-PSDrive C
$FreeGB = [math]::Round($DriveC.Free / 1GB, 1)
Write-Host "Spazio libero su disco host C: $FreeGB GB" -ForegroundColor Green

# Esecuzione del download con huggingface-cli dentro il venv WSL2
Write-Host ""
Write-Host "Avvio download e caching con huggingface-cli in WSL2..." -ForegroundColor Yellow
Write-Host "(Il download supporta ripresa automatica in caso di interruzione)" -ForegroundColor Gray
Write-Host ""

$BashCommand = "export NO_PROXY='localhost,127.0.0.1,::1,192.168.1.0/24'; " +
               "source /home/admin_ubuntu/vllm-env/bin/activate && " +
               "python3 -c `"import huggingface_hub; print('HuggingFace Hub version:', huggingface_hub.__version__)`" && " +
               "huggingface-cli download '$TargetRepo' --local-dir-use-symlinks True"

wsl.exe -d $Distro bash -c $BashCommand

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "   INSTALLAZIONE DEL MODELLO COMPLETATA CON SUCCESSO!     " -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "Il modello e' ora presente nella cache locale di vLLM." -ForegroundColor Green
    Write-Host ""
    Write-Host "Per avviarlo su vLLM Singolo PC (RTX 4070 8GB):" -ForegroundColor Cyan
    Write-Host "  .\scripts\run_vllm.ps1 -Model `"$TargetRepo`"" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Per visualizzarlo nella Web Chat UI:" -ForegroundColor Cyan
    Write-Host "  Apri o ricarica scripts\chat_ui.html e selezionalo dal menu in alto!" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "Download terminato con codice di errore: $LASTEXITCODE" -ForegroundColor Red
    Write-Host "Verifica la connessione di rete o se il repository richiede autenticazione Hugging Face (huggingface-cli login)." -ForegroundColor Yellow
}
