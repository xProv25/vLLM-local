#!/usr/bin/env bash
# ==============================================================================
# Launch Distributed vLLM on Ray Cluster (2 Nodes - 2x 12GB GPUs)
# Target Model: Qwen/Qwen2.5-32B-Instruct-AWQ
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PATH="${HOME}/vllm-env"

# Activate Virtual Environment
if [[ -f "${VENV_PATH}/bin/activate" ]]; then
    # shellcheck source=/dev/null
    source "${VENV_PATH}/bin/activate"
else
    echo "[-] Error: Virtual environment not found at ${VENV_PATH}"
    exit 1
fi

MODEL_NAME="${1:-Qwen/Qwen2.5-32B-Instruct-AWQ}"
if [[ $# -gt 0 ]]; then
    shift
fi

PARALLEL_STRATEGY="${PARALLEL_STRATEGY:-pp}" # 'pp' (Pipeline Parallelism) or 'tp' (Tensor Parallelism)
MAX_MODEL_LEN="${MAX_MODEL_LEN:-2048}"
GPU_MEM_UTIL="${GPU_MEM_UTIL:-0.92}"
CPU_OFFLOAD_GB="${CPU_OFFLOAD_GB:-3}"
PORT="${PORT:-8000}"
HOST="${HOST:-0.0.0.0}"
API_KEY="${API_KEY:-vllm-local-token}"

# Network and Ray environment
export NO_PROXY="localhost,127.0.0.1,192.168.1.100,192.168.1.101,192.168.1.0/24"
export no_proxy="localhost,127.0.0.1,192.168.1.100,192.168.1.101,192.168.1.0/24"
export HF_HUB_ENABLE_HF_TRANSFER=1
export NCCL_DEBUG=INFO
export NCCL_IB_DISABLE=1
export NCCL_NET_GDR_LEVEL=0
export NCCL_SOCKET_IFNAME="eth0,eth1,eth2,en,wlan"
export GLOO_SOCKET_IFNAME="eth0,eth1,eth2,en,wlan"
export VLLM_WORKER_MULTIPROC_METHOD=spawn

echo "=========================================================="
echo " Starting Distributed vLLM Cluster Inference Server"
echo "=========================================================="
echo " Model:                    ${MODEL_NAME}"
echo " Parallelism Mode:         ${PARALLEL_STRATEGY^^} (Size: 2 across 2 Nodes)"
echo " Context Length:           ${MAX_MODEL_LEN}"
echo " GPU Memory Utilization:   ${GPU_MEM_UTIL} (per GPU)"
echo " Host / Port:              ${HOST}:${PORT}"
echo " API Key:                  ${API_KEY}"
echo "=========================================================="

# Check Ray cluster status before starting
echo "[+] Checking Ray cluster nodes and GPUs..."
ray status || {
    echo "[-] Ray cluster is not running! Run ./scripts/start_head.sh first."
    exit 1
}

PARALLEL_ARGS=()
if [[ "${PARALLEL_STRATEGY,,}" == "pp" ]]; then
    echo "[*] Using Pipeline Parallelism (--pipeline-parallel-size 2)."
    echo "    RECOMMENDED: Low network traffic (activations transferred only at stage boundary)."
    PARALLEL_ARGS+=(--pipeline-parallel-size 2)
else
    echo "[*] Using Tensor Parallelism (--tensor-parallel-size 2)."
    echo "    NOTE: Requires high-frequency all-reduce per layer over Gigabit Ethernet."
    PARALLEL_ARGS+=(--tensor-parallel-size 2)
fi

EXTRA_ARGS=()
if [[ "${MODEL_NAME}" == *"AWQ"* ]] || [[ "${MODEL_NAME}" == *"awq"* ]]; then
    EXTRA_ARGS+=(--quantization awq)
fi

# On 2x 8GB nodes (16GB VRAM), 32B model (~19GB) requires ~3GB offload per node
if [[ "${MODEL_NAME}" == *"32B"* ]]; then
    if [[ "${CPU_OFFLOAD_GB}" -gt 0 ]]; then
        echo "[!] Notice: 32B model on 2x 8GB nodes detected. Applying --cpu-offload-gb ${CPU_OFFLOAD_GB} to fit ~9.5GB stage weights."
        EXTRA_ARGS+=(--cpu-offload-gb "${CPU_OFFLOAD_GB}")
    fi
fi

exec vllm serve "${MODEL_NAME}" \
    --host "${HOST}" \
    --port "${PORT}" \
    --max-model-len "${MAX_MODEL_LEN}" \
    --gpu-memory-utilization "${GPU_MEM_UTIL}" \
    --swap-space 1 \
    --enforce-eager \
    --api-key "${API_KEY}" \
    --trust-remote-code \
    "${PARALLEL_ARGS[@]}" \
    "${EXTRA_ARGS[@]}" \
    "$@"
