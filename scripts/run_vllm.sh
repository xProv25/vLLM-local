#!/usr/bin/env bash
# ==============================================================================
# vLLM Server Runner for WSL2
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VENV_PATH="${HOME}/vllm-env"

# Activate Python Virtual Environment
if [[ -f "${VENV_PATH}/bin/activate" ]]; then
    # shellcheck source=/dev/null
    source "${VENV_PATH}/bin/activate"
else
    echo "[-] Error: Virtual environment not found at ${VENV_PATH}"
    echo "    Run setup instructions first: uv venv --seed --python 3.12 ~/vllm-env"
    exit 1
fi

# Ensure nvidia tools & libraries are in PATH
export PATH="/usr/lib/wsl/lib:/usr/local/bin:${PATH}"
export LD_LIBRARY_PATH="/usr/lib/wsl/lib:${LD_LIBRARY_PATH:-}"

# Hugging Face performance optimizations
export HF_HUB_ENABLE_HF_TRANSFER=1
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export CUDA_VISIBLE_DEVICES=0

# Default model configuration
# Qwen2.5-32B-Instruct-AWQ weights are ~18.5GB.
# On a single 8GB/12GB GPU, weights exceed VRAM. We provide CPU offload option or fallback models.
MODEL_NAME="${1:-Qwen/Qwen2.5-32B-Instruct-AWQ}"
PORT="${PORT:-8000}"
HOST="${HOST:-0.0.0.0}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-2048}"
GPU_MEM_UTIL="${GPU_MEM_UTIL:-0.95}"
API_KEY="${API_KEY:-vllm-local-token}"
CPU_OFFLOAD_GB="${CPU_OFFLOAD_GB:-12}"

echo "=========================================================="
echo " Starting vLLM OpenAI-Compatible API Server"
echo "=========================================================="
echo " Model:                    ${MODEL_NAME}"
echo " Host / Port:              ${HOST}:${PORT}"
echo " Max Context Length:       ${MAX_MODEL_LEN}"
echo " GPU Memory Utilization:   ${GPU_MEM_UTIL}"
echo " CPU Offload (GB):         ${CPU_OFFLOAD_GB}"
echo " API Key:                  ${API_KEY}"
echo " Virtual Env:              ${VENV_PATH}"
echo "=========================================================="

EXTRA_ARGS=()

# Determine quantization and specific model parameters
if [[ "${MODEL_NAME}" == *"AWQ"* ]] || [[ "${MODEL_NAME}" == *"awq"* ]]; then
    EXTRA_ARGS+=(--quantization awq)
fi

# If using 32B on single GPU with <= 12GB VRAM, enforce eager execution and CPU offloading
if [[ "${MODEL_NAME}" == *"32B"* ]]; then
    echo "[!] Notice: 32B model detected. Applying --enforce-eager and --cpu-offload-gb ${CPU_OFFLOAD_GB} to prevent OOM on single GPU."
    EXTRA_ARGS+=(--enforce-eager)
    if [[ "${CPU_OFFLOAD_GB}" -gt 0 ]]; then
        EXTRA_ARGS+=(--cpu-offload-gb "${CPU_OFFLOAD_GB}")
    fi
else
    # For smaller models (e.g. 7B/14B), enforce eager can still be used if VRAM is tight
    EXTRA_ARGS+=(--enforce-eager)
fi

exec vllm serve "${MODEL_NAME}" \
    --host "${HOST}" \
    --port "${PORT}" \
    --max-model-len "${MAX_MODEL_LEN}" \
    --gpu-memory-utilization "${GPU_MEM_UTIL}" \
    --api-key "${API_KEY}" \
    --trust-remote-code \
    "${EXTRA_ARGS[@]}" \
    "$@"
