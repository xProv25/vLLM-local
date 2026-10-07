# Local vLLM Inference Environment (WSL2 + NVIDIA RTX)

Questo repository contiene la configurazione completa, gli script di automazione e gli strumenti di benchmark per l'esecuzione locale di Large Language Models (LLM) tramite **vLLM (0.6.3)** su architettura **Windows 11 con WSL2** e GPU NVIDIA RTX.

---

## 1. Analisi Hardware & Vincoli di Memoria VRAM

### Specifiche Rilevate sul Sistema Locale
- **Host OS**: Windows 11 Home / Pro
- **WSL2 Distro**: Ubuntu 26.04 LTS (Kernel Linux 6.6+)
- **GPU Rilevata**: NVIDIA GeForce RTX 4070 Laptop GPU (**8,188 MiB VRAM / ~8 GB**)
- **Driver NVIDIA Host**: 556.19 (CUDA 12.5)
- **Host RAM**: 16 GB DDR5
- **WSL2 Allocated RAM**: ~7.6 GB (Default WSL2) -> Raccomandato: **12 GB** tramite `.wslconfig`

### Il Caso "Qwen/Qwen2.5-32B-Instruct-AWQ"
Il modello **Qwen2.5-32B-Instruct-AWQ** adotta quantizzazione a 4-bit (INT4 AWQ).
- **Dimensione pesi del modello su disco/VRAM**: circa **18.5 - 19.5 GB**.
- **Memoria necessaria per KV Cache + Attivazioni**: 2 - 4 GB aggiuntivi (a seconda della lunghezza di contesto `max-model-len`).

#### Considerazioni Cruciali per la Fase 1 vs Fase 2:
1. **GPU da 12GB (es. RTX 4070 Ti Desktop)**:
   I pesi (18.5 GB) superano comunque i 12 GB fisici. Su una singola GPU da 12 GB, un modello 32B non può risiedere interamente in VRAM senza **CPU offloading** (`--cpu-offload-gb`) o senza partizionamento su più GPU.
2. **GPU da 8GB (RTX 4070 Laptop rilevata sul sistema)**:
   Il vincolo è ancora più stretto (8 GB VRAM disponibili).
3. **Strategia Fase 1 (Macchina Singola)**:
   - Per testare **Qwen2.5-32B-Instruct-AWQ** su singola macchina si utilizzano i parametri `--cpu-offload-gb 12` e `--enforce-eager` con contesto ridotto (`--max-model-len 2048`).
   - Per validare e benchmarkare l'infrastruttura vLLM a piena velocità GPU nativa (senza collo di bottiglia PCIe/RAM), si raccomanda di effettuare i test preliminari con **Qwen/Qwen2.5-7B-Instruct-AWQ** (~4.5 GB VRAM, 100% in GPU) o **Qwen/Qwen2.5-14B-Instruct-AWQ** (~8.5 GB VRAM).
4. **Fase 2 (Cluster Ray & Pipeline Parallelism)**:
   La distribuzione del modello 32B su 2 o più laptop (collegati in rete locale) tramite **Ray** e **Pipeline Parallelism (PP=2 o PP=3)** permetterà di dividere i layer del modello tra le GPU dei vari laptop (es. 8GB + 12GB = 20GB VRAM aggregata), consentendo l'esecuzione nativa a velocità massima.

---

## 2. Preparazione Ambiente WSL2 & Driver CUDA

WSL2 utilizza la tecnologia NVIDIA Container Toolkit / WSL-CUDA Direct:
- Non è necessario (ed è sconsigliato) installare il driver Linux NVIDIA all'interno di WSL2. I driver vengono erogati dall'host Windows tramite `/usr/lib/wsl/lib/libcuda.so.1`.
- È stato configurato il symlink di sistema per `nvidia-smi`:
  ```bash
  /usr/local/bin/nvidia-smi -> /usr/lib/wsl/lib/nvidia-smi
  ```

### Ottimizzazione Memoria WSL2 (`.wslconfig`)
Copiare il file fornito `.wslconfig.example` nella cartella utente di Windows per estendere RAM e swap:
```powershell
Copy-Item .wslconfig.example "$env:USERPROFILE\.wslconfig"
wsl --shutdown
```

---

## 3. Ambiente Virtuale Python & Installazione vLLM 0.6.3

L'ambiente virtuale dedicato è stato creato all'interno del filesystem nativo WSL2 (`~/vllm-env`) tramite **uv** con **Python 3.12**:

```bash
# Entra in WSL2
wsl -d Ubuntu

# Attivazione ambiente
source ~/vllm-env/bin/activate

# Verifica versione vLLM
vllm --version
# Output atteso: vllm 0.6.3
```

---

## 4. Parametri di Avvio Ottimizzati

| Parametro | Valore Raccomandato (32B) | Scopo Tecnico |
|---|---|---|
| `--model` | `Qwen/Qwen2.5-32B-Instruct-AWQ` | Checkpoint AWQ 4-bit |
| `--quantization` | `awq` | Abilita i kernel di decompressione INT4 AWQ |
| `--max-model-len` | `2048` | Riduce la VRAM allocata alla tabella KV Cache |
| `--gpu-memory-utilization` | `0.95` | Alloca il 95% della VRAM libera a vLLM |
| `--enforce-eager` | Flag attivo | Disabilita i grafi CUDA statici (risparmia ~1.5 - 2 GB di memoria statica) |
| `--cpu-offload-gb` | `12` | Scarica i layer eccedenti nella RAM di sistema |
| `--trust-remote-code` | Flag attivo | Supporto per l'architettura tokenizer/modello Qwen2.5 |

---

## 5. Script di Avvio Rapido

### Avvio da Linux / WSL2
```bash
# Avvio modello 32B con parametri ottimizzati
./scripts/run_vllm.sh Qwen/Qwen2.5-32B-Instruct-AWQ

# Oppure avvio benchmark nativo GPU (7B AWQ)
MAX_MODEL_LEN=8192 ./scripts/run_vllm.sh Qwen/Qwen2.5-7B-Instruct-AWQ
```

### Avvio diretto da Windows (PowerShell)
```powershell
# Avvio rapido
.\scripts\run_vllm.ps1

# Avvio con override parametri
.\scripts\run_vllm.ps1 -Model "Qwen/Qwen2.5-7B-Instruct-AWQ" -MaxModelLen 4096 -GpuMemUtil 0.90
```

---

## 6. Test e Benchmark API (OpenAI Compatible)

vLLM espone API compatibili OpenAI sulla porta `8000`.

### 1. Test Rapido cURL (Bash / WSL2)
```bash
./scripts/test_api.sh
```

### 2. Test Rapido PowerShell (Windows)
```powershell
.\scripts\test_api.ps1
```

### 3. Benchmark Dettagliato (TTFT & Throughput TPS)
Lo script `scripts/benchmark_client.py` misura:
- **TTFT (Time To First Token)** in millisecondi
- **TPS (Tokens Per Second)** per singola richiesta
- **Throughput aggregato di sistema** a vari livelli di concorrenza

```bash
# Esecuzione benchmark su richiesta singola
python scripts/benchmark_client.py --model "Qwen/Qwen2.5-32B-Instruct-AWQ"

# Esecuzione benchmark di carico con concorrenza 4
python scripts/benchmark_client.py --concurrency 4 --max-tokens 512
```

---

## 7. Prospettiva Fase 2: Cluster Distribuito con Ray

Nella seconda fase configureremo:
1. **Ray Head Node** sul laptop primario.
2. **Ray Worker Node(s)** sugli altri laptop in rete LAN (Wi-Fi 6 o Ethernet 2.5G).
3. **Pipeline Parallelism (`--pipeline-parallel-size 2` o `3`)**:
   Distribuzione sequenziale dei 64 layer del modello 32B tra le macchine, consentendo a ciascun laptop di caricare solo 6-8 GB di pesi, sfruttando al 100% la VRAM senza degradazione da CPU swapping.
