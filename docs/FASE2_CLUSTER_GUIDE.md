# Guida Operativa: Cluster Distribuito vLLM a 2 Nodi (Fase 2)

Questa guida documenta la procedura completa per configurare, avviare e testare un cluster di inferenza distribuito locale basato su **vLLM (0.6.3)** e **Ray (2.38.0)** su due computer (Windows 11 con WSL2 e GPU NVIDIA RTX).

---

## 1. Architettura Hardware e Strategia di Parallelismo

### Specifiche Hardware Complessive
- **Topologia**: 2 Nodi (1 Head Node / Master + 1 Worker Node)
- **VRAM Aggregata**: **16 GB** (2 x 8 GB GDDR6, es. RTX 4070 Laptop)
- **VRAM Utile per Nodo**: ~7.0 - 7.2 GB (al netto dell'overhead del display Windows)
- **Modello Target**: **`Qwen/Qwen2.5-32B-Instruct-AWQ`**
  - Dimensione pesi su disco/VRAM: ~18.5 - 19.5 GB.
  - **Su 2 nodi da 8 GB (Pipeline Parallelism PP=2)**:
    Ciascun nodo gestisce 32 layer (~9.5 GB di pesi). Poiché la VRAM per GPU è di 8 GB, ciascun nodo alloca ~6.8 GB in GPU e scarica un piccolo residuo di soli **~2.8 - 3 GB in RAM di sistema** (`--cpu-offload-gb 3`).
    *(Confronto con nodo singolo: l'offload crolla da 12 GB a soli 3 GB per nodo, riducendo drasticamente il collo di bottiglia RAM/PCIe).*
  - **Alternativa 100% VRAM (Zero CPU Offload)**:
    Il modello **`Qwen/Qwen2.5-14B-Instruct-AWQ`** (~8.5 GB pesi totali) richiede solo **~4.25 GB per GPU**, risiedendo interamente nella VRAM da 8 GB con zero offload e massima velocità Gigabit.
  - **Espansione a 3 Nodi (3x 8GB = 24GB)**:
    Con 3 laptop da 8 GB (PP=3), il modello 32B richiede solo ~6.3 GB per nodo ed entra al 100% in VRAM pura senza alcun CPU offloading.

### Confronto Tecnico: Pipeline Parallelism (PP) vs Tensor Parallelism (TP) su Rete Gigabit (1 Gbps)

La velocità della connessione Ethernet Gigabit (1 Gbps = ~110-125 MB/s effettivi) impone una scelta precisa della tecnica di parallelizzazione:

| Caratteristica | Pipeline Parallelism (`--pipeline-parallel-size 2`) | Tensor Parallelism (`--tensor-parallel-size 2`) |
|---|---|---|
| **Punto di Scambio Dati** | Solo al confine tra Stage 0 e Stage 1 (dopo il layer 32) | Su **ogni singolo layer** (64 volte per token generato) |
| **Operazione di Rete** | Trasferimento p2p del tensore delle attivazioni intermedie | All-Reduce collettivo sincrono (NCCL ring/tree) |
| **Volume Dati per Token** | ~100 KB - 500 KB per token | Decine di MegaByte per token (centinaia di MB/s) |
| **Impatto Rete 1 Gbps** | **Ottimale e fluido**: il link da 1 Gbps non satura | **Forte collo di bottiglia**: attese costanti su socket NCCL |
| **Raccomandazione** | **RACCOMANDATO (Scelta predefinita per switch Gigabit)** | Riservato a cluster con link ad alta velocità (10G/40G/NVLink) |

---

## 2. Piano di Rete & Indirizzamento IP Statico

Per garantire latenze deterministiche ed eliminare interferenze:
- **Switch Ethernet**: Switch Gigabit (o 2.5G) dedicato con cavi **Cat6**.
- **Wi-Fi**: Disattivato su entrambi i computer durante l'esecuzione del cluster per forzare l'instradamento esclusivo su interfaccia cablata.

| Ruolo | Hostname Logico | IP Statico Ethernet | Subnet Mask | Gateway |
|---|---|---|---|---|
| **Head Node (Master)** | `vllm-head` | `192.168.1.100` | `255.255.255.0` (/24) | `192.168.1.1` (o vuoto se isolato) |
| **Worker Node** | `vllm-worker` | `192.168.1.101` | `255.255.255.0` (/24) | `192.168.1.1` (o vuoto se isolato) |

---

## 3. Configurazione da Applicare su Entrambi i Nodi

### Passo 1: Configurazione WSL2 (`networkingMode=mirrored`)
In modalità standard NAT, WSL2 assegna un IP virtuale non raggiungibile dall'esterno. La modalità **mirrored** condivide direttamente lo stack di rete dell'host Windows.

1. Copiare la configurazione di cluster in `%USERPROFILE%\.wslconfig`:
   ```powershell
   Copy-Item .\config\.wslconfig.cluster "$env:USERPROFILE\.wslconfig"
   ```
2. Riavviare il sottosistema WSL per applicare la modalità mirrored:
   ```powershell
   wsl --shutdown
   ```
3. Verifica in WSL:
   ```bash
   wsl -d Ubuntu -e ip a
   # L'interfaccia eth0 mostrerà direttamente l'IP 192.168.1.100 (o .101)
   ```

### Passo 2: Apertura Porte nel Firewall di Windows
Eseguire da Windows PowerShell con privilegi di **Amministratore**:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup_firewall.ps1
```
Porte aperte automaticamente:
- **TCP 6379**: Ray GCS Master Core
- **TCP 8265**: Ray Web Dashboard
- **TCP 10000-10200**: Ray Worker Process Ports
- **TCP 8000**: vLLM OpenAI API HTTP Server
- **TCP 29500**: PyTorch Distributed Master Rendezvous
- **TCP 30000-65535**: NCCL Dynamic High-Socket Transport

### Passo 3: Configurazione IP Statico
Da Windows PowerShell (come Amministratore):
- **Sull'Head Node**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\scripts\setup_network.ps1 -Role Head -DisableWifi
  ```
- **Sul Worker Node**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\scripts\setup_network.ps1 -Role Worker -DisableWifi
  ```

---

## 4. Installazione Ambiente Python (Sul Nodo Worker)

Sul secondo computer (Worker), clonare il repository ed eseguire il setup:

```bash
# 1. Clona il repository privato con il tuo GitHub Personal Access Token
git clone https://<GITHUB_TOKEN>@github.com/xProv25/vLLM-local.git
cd vLLM-local

# 2. Installa uv (se non presente) e crea l'ambiente Python 3.12
curl -LsSf https://astral.sh/uv/install.sh | sh
~/.local/bin/uv venv --seed --python 3.12 ~/vllm-env

# 3. Installa le dipendenze identiche al master
source ~/vllm-env/bin/activate
~/.local/bin/uv pip install -r requirements.txt
```

---

## 5. Sequenza di Avvio e Orchestrazione del Cluster

### Fase A: Avvio del Nodo Master (Head Node)
Sull'Head Node (`192.168.1.100`), avviare Ray Head:

- **Da Bash**:
  ```bash
  ./scripts/start_head.sh
  ```
- **Oppure da Windows PowerShell**:
  ```powershell
  .\scripts\start_head.ps1
  ```

L'output confermerà l'avvio del master e l'URL della dashboard: `http://192.168.1.100:8265`.

---

### Fase B: Connessione del Nodo Worker
Sul Worker Node (`192.168.1.101`), collegarsi al master:

- **Da Bash**:
  ```bash
  ./scripts/start_worker.sh 192.168.1.100
  ```
- **Oppure da Windows PowerShell**:
  ```powershell
  .\scripts\start_worker.ps1 -HeadIp "192.168.1.100"
  ```

---

### Fase C: Verifica Stato Cluster Ray
Dall'Head Node, lanciare il comando di verifica:

```bash
wsl -d Ubuntu -e ray status
```

**Esito atteso per il cluster operativo a 2 nodi**:
```
======== Ray status ========
Active Nodes: 2
  - Node 192.168.1.100 (Head Node)
  - Node 192.168.1.101 (Worker Node)

Cluster Resources:
  - GPU: 2.0 / 2.0 (1.0 su Head, 1.0 su Worker)
  - CPU: 32.0 / 32.0
  - Memory: ~24.0 GiB
```

---

### Fase D: Avvio del Servizio vLLM Distribuito (Qwen2.5-32B)
Una volta rilevate entrambe le GPU (`2.0/2.0 GPUs`), avviare vLLM dall'Head Node:

- **Avvio Ottimizzato Pipeline Parallelism (Consigliato su Gigabit)**:
  ```bash
  ./scripts/run_vllm_cluster.sh Qwen/Qwen2.5-32B-Instruct-AWQ
  ```
- **Oppure da Windows PowerShell**:
  ```powershell
  .\scripts\run_vllm_cluster.ps1 -Model "Qwen/Qwen2.5-32B-Instruct-AWQ" -Strategy pp -MaxModelLen 4096
  ```

---

## 6. Test e Benchmark di Inferenza (`benchmark_serving`)

A cluster avviato, verificare e misurare le prestazioni dall'Head Node:

### 1. Test Rapido Risposta
```powershell
.\scripts\test_api.ps1 -Model "Qwen/Qwen2.5-32B-Instruct-AWQ"
```

### 2. Benchmark Completo Throughput & Latenza
```bash
# Test streaming singolo con misurazione TTFT e Inter-Token Latency (ITL)
python scripts/benchmark_serving.py --model "Qwen/Qwen2.5-32B-Instruct-AWQ" --max-tokens 256 --warmup

# Test di carico con 4 client concorrenti
python scripts/benchmark_serving.py --model "Qwen/Qwen2.5-32B-Instruct-AWQ" --concurrency 4 --max-tokens 256
```

---

## 7. Risoluzione dei Problemi Più Comuni (Troubleshooting)

1. **Timeout di Connessione Ray (`Connection refused` su porta 6379)**:
   - Verificare che il cavo Cat6 sia inserito e che il ping funzioni: `ping 192.168.1.100` dal worker.
   - Verificare che il firewall di Windows sull'Head Node abbia le regole attive eseguendo `.\scripts\setup_firewall.ps1`.
2. **Timeout NCCL (`NCCL WARN Socket connection timeout`)**:
   - Assicurarsi che `NCCL_IB_DISABLE=1` sia esportato (gestito automaticamente dai nostri script).
   - Verificare che `NCCL_SOCKET_IFNAME` punti all'interfaccia corretta.
3. **Interferenza Proxy (`HTTP_PROXY`)**:
   - Gli script impostano automaticamente `NO_PROXY` per tutta la subnet `192.168.1.0/24`, impedendo a eventuali proxy di rete locali o aziendali di intercettare il traffico interno del cluster.
