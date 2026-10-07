#!/usr/bin/env bash
# Quick curl test for vLLM OpenAI-compatible endpoint with wait loop
set -euo pipefail

export NO_PROXY="localhost,127.0.0.1,::1"
export no_proxy="localhost,127.0.0.1,::1"

BASE_URL="${1:-http://localhost:8000}"
API_KEY="${2:-vllm-local-token}"

echo ">>> 1. Checking models list on ${BASE_URL}..."

MAX_RETRIES=15
SUCCESS=0

for ((i=1; i<=MAX_RETRIES; i++)); do
    if curl --noproxy "*" -s -f -X GET "${BASE_URL}/v1/models" -H "Authorization: Bearer ${API_KEY}" > /dev/null 2>&1; then
        SUCCESS=1
        break
    else
        echo "    [*] Il server vLLM sta caricando il modello in GPU... (tentativo $i/$MAX_RETRIES)"
        sleep 3
    fi
done

if [[ $SUCCESS -eq 0 ]]; then
    echo "[-] Errore: il server su ${BASE_URL} non risponde ancora."
    echo "    Attendi che nel Terminale 1 compaia 'INFO: Uvicorn running on http://0.0.0.0:8000'."
    exit 1
fi

MODELS_JSON="$(curl --noproxy "*" -s -X GET "${BASE_URL}/v1/models" -H "Authorization: Bearer ${API_KEY}")"
echo "Available Models:"
echo "${MODELS_JSON}" | grep -o '"id":"[^"]*' | cut -d'"' -f4 || echo "${MODELS_JSON}"

FIRST_MODEL="$(echo "${MODELS_JSON}" | grep -o '"id":"[^"]*' | head -n 1 | cut -d'"' -f4 || echo "Qwen/Qwen2.5-7B-Instruct-AWQ")"

echo -e "\n>>> 2. Testing Chat Completion with '${FIRST_MODEL}'..."
curl --noproxy "*" -s -X POST "${BASE_URL}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_KEY}" \
  -d "{
    \"model\": \"${FIRST_MODEL}\",
    \"messages\": [
      {\"role\": \"system\", \"content\": \"Sei un assistente AI veloce e preciso.\"},
      {\"role\": \"user\", \"content\": \"Ciao! Sei operativo? Rispondi in una sola frase.\"}
    ],
    \"max_tokens\": 64,
    \"temperature\": 0.3
  }" || true
echo ""
