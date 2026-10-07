# Guida Rapida: Avvio e Test su Singolo PC (Fase 1)

I pesi del modello **`Qwen/Qwen2.5-7B-Instruct-AWQ`** (~4.5 GB) sono **già scaricati e memorizzati nella cache locale** di questo computer. L'avvio impiega solo circa 5-10 secondi!

---

## Passo 1: Avvia il Server vLLM (Terminale 1)

Apri una finestra di **PowerShell** (o terminale Bash WSL) in questa cartella (`C:\Users\ADMIN\Desktop\vLLM`):

### Da Windows PowerShell:
```powershell
.\scripts\run_vllm.ps1 -Model "Qwen/Qwen2.5-7B-Instruct-AWQ"
```

### Oppure da Bash in WSL2:
```bash
./scripts/run_vllm.sh Qwen/Qwen2.5-7B-Instruct-AWQ
```

> **Cosa succede ora?**
> Il server caricherà i pesi nella VRAM della GPU RTX 4070 Laptop, allocherà la KV Cache e stamperà:
> `INFO: Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)`
> **Lascia questo terminale aperto** mentre il server è in esecuzione.

---

## Passo 2: Testa l'API Chat (Terminale 2)

Apri un **secondo terminale** nella stessa cartella ed esegui la richiesta di test:

### Da Windows PowerShell:
```powershell
.\scripts\test_api.ps1 -Model "Qwen/Qwen2.5-7B-Instruct-AWQ"
```

### Oppure da Bash in WSL2:
```bash
./scripts/test_api.sh
```

**Esito atteso**:
Il modello risponderà con un messaggio in italiano (es. *"Sì, sono operativo e prontissimo ad aiutarti!"*).

---

## Passo 3: Esegui il Benchmark delle Prestazioni

Nel secondo terminale, misura la velocità di generazione (tokens/s) e la latenza del primo token (TTFT):

### Da Windows PowerShell:
```powershell
wsl -d Ubuntu -e bash -c "source ~/vllm-env/bin/activate && python scripts/benchmark_client.py --max-tokens 256"
```

### Oppure da Bash in WSL2:
```bash
python scripts/benchmark_client.py --max-tokens 256
```

Per testare la capacità sotto carico parallelo (4 richieste in contemporanea):
```bash
python scripts/benchmark_client.py --concurrency 4 --max-tokens 128
```

---

## Vuoi testare il 32B su questo singolo PC?

Se vuoi provare a caricare il modello **`Qwen/Qwen2.5-32B-Instruct-AWQ`** su questo singolo PC da 8 GB di VRAM, è necessario abilitare 12 GB di CPU offload (il primo avvio richiederà il download di ~19 GB):

```powershell
.\scripts\run_vllm.ps1 -Model "Qwen/Qwen2.5-32B-Instruct-AWQ" -MaxModelLen 2048 -CpuOffloadGb 12
```
