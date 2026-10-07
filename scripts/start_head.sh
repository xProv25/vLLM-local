#!/usr/bin/env bash
# ==============================================================================
# Start Ray Head Node (Master) - Phase 2 Cluster
# Node IP: 192.168.1.100 (Static)
# Hardware: RTX 4070 Laptop / Ti (12GB VRAM allocation: --num-gpus=1)
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

HEAD_IP="${HEAD_IP:-192.168.1.100}"
RAY_PORT="${RAY_PORT:-6379}"
DASHBOARD_PORT="${DASHBOARD_PORT:-8265}"
MIN_WORKER_PORT="${MIN_WORKER_PORT:-10000}"
MAX_WORKER_PORT="${MAX_WORKER_PORT:-10200}"

echo "=========================================================="
echo " Starting Ray Cluster HEAD Node (Master)"
echo "=========================================================="
echo " Head Node IP:             ${HEAD_IP}"
echo " Ray GCS Port:             ${RAY_PORT}"
echo " Ray Dashboard Port:       ${DASHBOARD_PORT} (http://${HEAD_IP}:${DASHBOARD_PORT})"
echo " Worker Port Range:        ${MIN_WORKER_PORT}-${MAX_WORKER_PORT}"
echo " GPUs Allocated on Head:   1"
echo "=========================================================="

# 1. Stop any existing Ray instances forcefully
echo "[+] Stopping previous Ray sessions..."
ray stop --force >/dev/null 2>&1 || true
sleep 2

# 2. Kill any stale processes on key cluster ports
fuser -k "${RAY_PORT}/tcp" >/dev/null 2>&1 || true
fuser -k "${DASHBOARD_PORT}/tcp" >/dev/null 2>&1 || true

# 3. Environment variables for NCCL and GLOO over Gigabit Ethernet
export NCCL_DEBUG=INFO
export NCCL_IB_DISABLE=1                          # No InfiniBand on consumer laptops
export NCCL_NET_GDR_LEVEL=0                       # Disable GPUDirect RDMA over standard LAN
export NCCL_SOCKET_IFNAME="eth0,eth1,eth2,en,wlan" # Match active network interface
export GLOO_SOCKET_IFNAME="eth0,eth1,eth2,en,wlan"
export RAY_DEDUP_LOGS=0

# Ensure cluster traffic bypasses any WSL/system HTTP proxies
export NO_PROXY="localhost,127.0.0.1,192.168.1.100,192.168.1.101,192.168.1.0/24,${HEAD_IP}"
export no_proxy="localhost,127.0.0.1,192.168.1.100,192.168.1.101,192.168.1.0/24,${HEAD_IP}"

# 4. Start Ray Head
echo "[+] Starting Ray Head Daemon..."
ray start --head \
    --node-ip-address="${HEAD_IP}" \
    --port="${RAY_PORT}" \
    --dashboard-host="0.0.0.0" \
    --dashboard-port="${DASHBOARD_PORT}" \
    --num-gpus=1 \
    --min-worker-port="${MIN_WORKER_PORT}" \
    --max-worker-port="${MAX_WORKER_PORT}" \
    --include-dashboard=true

echo ""
echo "[+] Verifying Head Node status..."
sleep 2
ray status

echo ""
echo "=========================================================="
echo " [SUCCESS] Ray Head Node is ONLINE!"
echo " Worker nodes can now connect using:"
echo "   ray start --address='${HEAD_IP}:${RAY_PORT}' --num-gpus=1"
echo "=========================================================="
