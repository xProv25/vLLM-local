# Guida Integrazione LM Studio & vLLM

Questa guida spiega la relazione architetturale tra **vLLM** e **LM Studio**, il motivo per cui i modelli scaricati per vLLM non compaiono automaticamente in LM Studio, e come gestirli/utilizzarli in entrambi gli ambienti.

---

## 1. Perché LM Studio non vede automaticamente i modelli di vLLM?

Esiste una differenza sostanziale di formato e motore tra i due strumenti:

| Proprietà | vLLM (Ambiente WSL2) | LM Studio (Desktop Windows) |
| :--- | :--- | :--- |
| **Motore di Inferenza** | PyTorch + CUDA + vLLM PagedAttention | `llama.cpp` (NVIDIA CUDA 12) |
| **Formato Modelli** | Hugging Face Safetensors (**AWQ**, GPTQ, BF16) | **GGUF** |
| **Percorso File** | Linux WSL2 (`~/.cache/huggingface/hub/`) | Windows (`C:\Users\ADMIN\.lmstudio\models\`) |
| **Ruolo Primario** | Server di inferenza headless ad alto throughput e cluster | Desktop GUI autonoma per esecuzione e test locale |
| **Porta API Default** | `http://localhost:8000/v1` | `http://localhost:1234/v1` |

I modelli scaricati con vLLM (es. `Qwen/Qwen2.5-7B-Instruct-AWQ`) sono file Safetensors ottimizzati specificamente per l'architettura GPU e PagedAttention. Il motore `llama.cpp` di LM Studio **non supporta i file Safetensors grezzi o AWQ**, ma richiede file quantizzati in formato **`.gguf`**.

---

## 2. Soluzione A: Avere il modello nativo dentro LM Studio (Formato GGUF)

Se desideri gestire ed eseguire il modello direttamente dalla GUI di LM Studio (per visualizzarlo nella scheda "My Models", selezionarlo nel menu a tendina della chat e caricarlo sulla GPU):

### Metodo 1: Tramite lo script rapido automatizzato
Abbiamo preparato uno script PowerShell dedicato che usa la CLI di LM Studio (`lms.exe`) per scaricare la quantizzazione ottimale per la tua GPU (RTX 4070 8GB):
```powershell
.\scripts\install_lmstudio_model.ps1 -Model "qwen2.5-7b-instruct"
```
Questo comando scarica automaticamente la versione **GGUF Q4_K_M** (~4.7 GB) e la inserisce in `C:\Users\ADMIN\.lmstudio\models\`.

### Metodo 2: Direttamente dall'interfaccia grafica di LM Studio
1. Apri **LM Studio**.
2. Clicca sull'icona della **Lente d'ingrandimento (Search)** nella barra laterale sinistra.
3. Nella barra di ricerca scrivi: `Qwen 2.5 7B Instruct`.
4. Tra i risultati, individua la voce con il tag **GGUF** (es. `Qwen/Qwen2.5-7B-Instruct-GGUF` o `bartowski/Qwen2.5-7B-Instruct-GGUF`).
5. Seleziona la variante quantizzata raccomandata: **`Q4_K_M`** (o `Q5_K_M`), ideale per gli 8 GB di VRAM.
6. Clicca sul pulsante **Download**.
7. Al termine, vai nella scheda **Chat** (icona fumetto) e seleziona il modello nel menu a tendina superiore per iniziare a chattare.

---

## 3. Soluzione B: Usare una Web GUI / Client per gestire il Server vLLM già attivo

Se il server vLLM è già in esecuzione su WSL2 (`http://localhost:8000/v1`) con il modello `Qwen/Qwen2.5-7B-Instruct-AWQ` e desideri un'interfaccia grafica reattiva tipo ChatGPT (senza riscaricare 5 GB di modello):

### Opzione 1: Web Chat UI Locale inclusa nel progetto
Abbiamo creato un'interfaccia Web moderna, scura e reattiva con streaming in tempo reale inclusa in questo repository:
```powershell
.\scripts\open_chat_ui.ps1
```
Caratteristiche:
- Rileva automaticamente i modelli serviti da vLLM (`/v1/models`).
- Supporta streaming token-by-token ad altissima velocità.
- Permette di regolare Temperatura, Top-P, Max Tokens e System Prompt.
- Funziona offline direttamente nel tuo browser preferito (Edge/Chrome).

### Opzione 2: Client Desktop di terze parti (Chatbox / Open WebUI)
Puoi collegare qualsiasi client OpenAI-compatibile inserendo:
- **API Host / Base URL:** `http://localhost:8000/v1`
- **API Key:** `vllm-local-token`
- **Model:** `Qwen/Qwen2.5-7B-Instruct-AWQ`
