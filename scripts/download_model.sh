#!/usr/bin/env bash
# ==============================================================================
# Script di download e caching modelli per vLLM (WSL2 / Linux)
# ==============================================================================

set -euo pipefail

MODEL_INPUT="${1:-qwen-7b}"

declare -A CATALOG=(
    ["qwen-7b"]="Qwen/Qwen2.5-7B-Instruct-AWQ"
    ["deepseek-r1-7b"]="casperhansen/deepseek-r1-distill-qwen-7b-awq"
    ["llama-3.2-3b"]="meta-llama/Llama-3.2-3B-Instruct"
    ["mistral-7b"]="solidrust/Mistral-7B-Instruct-v0.3-AWQ"
    ["qwen-32b"]="Qwen/Qwen2.5-32B-Instruct-AWQ"
)

TARGET_MODEL="$MODEL_INPUT"
if [[ -v "CATALOG[$MODEL_INPUT]" ]]; then
    TARGET_MODEL="${CATALOG[$MODEL_INPUT]}"
fi

echo "=========================================================="
echo "   vLLM - DOWNLOAD MODELLO: $TARGET_MODEL"
echo "=========================================================="

export NO_PROXY="localhost,127.0.0.1,::1,192.168.1.0/24"
source /home/admin_ubuntu/vllm-env/bin/activate

echo "Avvio download con huggingface-cli..."
huggingface-cli download "$TARGET_MODEL" --local-dir-use-symlinks True

echo ""
echo "Download completato con successo: $TARGET_MODEL"
