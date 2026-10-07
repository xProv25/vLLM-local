#!/usr/bin/env bash
# ==============================================================================
# Start Ray Worker Node - Phase 2 Cluster
# Target Head Node IP: 192.168.1.100:6379
# Target Worker IP:    192.168.1.101 (or dynamically detected)
# Hardware: RTX 4070 Laptop (8GB VRAM allocation: --num-gpus=1)
# ==============================================================================
set -euo pipefail

VENV_PATH="${HOME}/vllm-env"

# Activate Virtual Environment
if [[ -f "${VENV_PATH}/bin/activate" ]]; then
    # shellcheck source=/dev/null
    source "${VENV_PATH}/bin/activate"
else
    echo "[-] Error: Virtual environment not found at ${VENV_PATH}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python "${SCRIPT_DIR}/patch_ray.py" >/dev/null 2>&1 || true

HEAD_IP="${1:-${HEAD_IP:-192.168.1.100}}"
HEAD_PORT="${HEAD_PORT:-6379}"
HEAD_ADDRESS="${HEAD_IP}:${HEAD_PORT}"

# Dynamic or static detection of local IP address
DETECTED_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
LOCAL_IP="${LOCAL_IP:-${DETECTED_IP:-192.168.1.101}}"

MIN_WORKER_PORT="${MIN_WORKER_PORT:-10000}"
MAX_WORKER_PORT="${MAX_WORKER_PORT:-10200}"

echo "=========================================================="
echo " Starting Ray Cluster WORKER Node"
echo "=========================================================="
echo " Local Worker IP:          ${LOCAL_IP}"
echo " Connecting to Head:       ${HEAD_ADDRESS}"
echo " Worker Port Range:        ${MIN_WORKER_PORT}-${MAX_WORKER_PORT}"
echo " GPUs Allocated on Worker: 1"
echo "=========================================================="

# 1. Stop any existing Ray instances
echo "[+] Stopping previous Ray sessions..."
ray stop --force >/dev/null 2>&1 || true
sleep 2

# 2. Environment variables for NCCL and GLOO over Gigabit Ethernet
export NCCL_DEBUG=INFO
export NCCL_IB_DISABLE=1
export NCCL_NET_GDR_LEVEL=0
export NCCL_SOCKET_IFNAME="eth0,eth1,eth2,en,wlan"
export GLOO_SOCKET_IFNAME="eth0,eth1,eth2,en,wlan"
export RAY_DEDUP_LOGS=0

# Ensure cluster traffic bypasses any proxy
export NO_PROXY="localhost,127.0.0.1,192.168.1.100,192.168.1.101,192.168.1.0/24,${HEAD_IP},${LOCAL_IP}"
export no_proxy="localhost,127.0.0.1,192.168.1.100,192.168.1.101,192.168.1.0/24,${HEAD_IP},${LOCAL_IP}"

# 3. Test basic reachability of Head node
echo "[+] Checking connection to Head node at ${HEAD_IP}:${HEAD_PORT}..."
if command -v nc >/dev/null 2>&1; then
    if ! nc -z -w 3 "${HEAD_IP}" "${HEAD_PORT}"; then
        echo "[!] WARNING: Unable to reach ${HEAD_IP}:${HEAD_PORT}. Verify Cat6 cable and Head node status."
    fi
fi

# 4. Connect Worker to Ray Cluster
echo "[+] Connecting Worker to Ray Cluster..."
ray start \
    --address="${HEAD_ADDRESS}" \
    --node-ip-address="${LOCAL_IP}" \
    --num-gpus=1 \
    --min-worker-port="${MIN_WORKER_PORT}" \
    --max-worker-port="${MAX_WORKER_PORT}"

echo ""
echo "=========================================================="
echo " [SUCCESS] Worker node connected to cluster at ${HEAD_ADDRESS}!"
echo " Check cluster status on Head node using: ray status"
echo "=========================================================="
