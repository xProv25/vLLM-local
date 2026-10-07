#!/usr/bin/env bash
# Quick curl test for vLLM OpenAI-compatible endpoint
set -euo pipefail

export NO_PROXY="localhost,127.0.0.1,::1"
export no_proxy="localhost,127.0.0.1,::1"

BASE_URL="${1:-http://localhost:8000}"
API_KEY="${2:-vllm-local-token}"

echo ">>> 1. Checking models list..."
curl --noproxy "*" -s -X GET "${BASE_URL}/v1/models" \
  -H "Authorization: Bearer ${API_KEY}" | jq . || curl -s -X GET "${BASE_URL}/v1/models" -H "Authorization: Bearer ${API_KEY}"

echo -e "\n>>> 2. Testing Chat Completion..."
curl --noproxy "*" -s -X POST "${BASE_URL}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_KEY}" \
  -d '{
    "model": "Qwen/Qwen2.5-32B-Instruct-AWQ",
    "messages": [
      {"role": "system", "content": "Sei un assistente AI veloce e preciso."},
      {"role": "user", "content": "Ciao! Sei operativo? Rispondi in una sola frase."}
    ],
    "max_tokens": 64,
    "temperature": 0.3
  }' | jq . || true
echo ""
