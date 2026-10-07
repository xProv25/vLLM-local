<#
.SYNOPSIS
    Launches Distributed vLLM Server on 2 Nodes from Windows PowerShell.
#>
param(
    [string]$Model = "Qwen/Qwen2.5-32B-Instruct-AWQ",
    [ValidateSet("pp", "tp")]
    [string]$Strategy = "pp",
    [int]$MaxModelLen = 4096,
    [double]$GpuMemUtil = 0.92,
    [int]$Port = 8000
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Launching Distributed vLLM on Ray Cluster" -ForegroundColor Green
Write-Host " Model:             $Model" -ForegroundColor White
Write-Host " Strategy:          $($Strategy.ToUpper()) (Size: 2)" -ForegroundColor White
Write-Host " Max Model Len:     $MaxModelLen" -ForegroundColor White
Write-Host " GPU Mem Util:      $GpuMemUtil (per GPU)" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

$wslCmd = "export PARALLEL_STRATEGY=$Strategy; export MAX_MODEL_LEN=$MaxModelLen; export GPU_MEM_UTIL=$GpuMemUtil; export PORT=$Port; /mnt/c/Users/ADMIN/Desktop/vLLM/scripts/run_vllm_cluster.sh '$Model'"
wsl -d Ubuntu -e bash -c $wslCmd
