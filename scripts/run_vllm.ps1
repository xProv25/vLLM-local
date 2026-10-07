<#
.SYNOPSIS
    Launch vLLM server inside WSL2 from Windows PowerShell.

.DESCRIPTION
    Forwards invocation and parameters directly into Ubuntu WSL2 environment.

.EXAMPLE
    .\scripts\run_vllm.ps1
    .\scripts\run_vllm.ps1 -Model "Qwen/Qwen2.5-7B-Instruct-AWQ"
    .\scripts\run_vllm.ps1 -Model "Qwen/Qwen2.5-32B-Instruct-AWQ" -MaxModelLen 2048
#>
param(
    [string]$Model = "Qwen/Qwen2.5-32B-Instruct-AWQ",
    [int]$MaxModelLen = 2048,
    [double]$GpuMemUtil = 0.95,
    [int]$CpuOffloadGb = 12,
    [string]$HostIp = "0.0.0.0",
    [int]$Port = 8000,
    [string]$ApiKey = "vllm-local-token"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Launching vLLM inside WSL2 (Ubuntu)" -ForegroundColor Green
Write-Host " Model:               $Model" -ForegroundColor White
Write-Host " Max Model Len:       $MaxModelLen" -ForegroundColor White
Write-Host " GPU Mem Util:        $GpuMemUtil" -ForegroundColor White
Write-Host " CPU Offload (GB):    $CpuOffloadGb" -ForegroundColor White
Write-Host " Endpoint:            http://$HostIp`:$Port" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

$scriptDirWsl = (wsl -d Ubuntu -e wslpath -a -u ($PSScriptRoot -replace '\\', '/')).Trim()
$wslCmd = "export MAX_MODEL_LEN=$MaxModelLen; export GPU_MEM_UTIL=$GpuMemUtil; export CPU_OFFLOAD_GB=$CpuOffloadGb; export PORT=$Port; export HOST=$HostIp; export API_KEY=$ApiKey; $scriptDirWsl/run_vllm.sh '$Model'"
wsl -d Ubuntu -e bash -c $wslCmd
