#!/usr/bin/env python3
"""
vLLM Local Studio - Model Management Helper Server
Micro-servizio locale (porta 8001) per gestione, installazione ed eliminazione modelli dalla Web UI.
"""

import http.server
import json
import os
import shutil
import socket
import subprocess
import threading
import time
import urllib.parse
from pathlib import Path

PORT = 8001
HOST = "127.0.0.1"

# Percorsi cache
WSL_HF_CACHE_WIN = Path(r"\\wsl.localhost\Ubuntu\home\admin_ubuntu\.cache\huggingface\hub")
LMSTUDIO_MODELS_WIN = Path(os.path.expanduser(r"~/.lmstudio/models"))

# Stato job corrente
current_job = {
    "status": "idle",  # idle, downloading, completed, error
    "model": None,
    "log": "",
    "start_time": None,
    "error": None
}
job_lock = threading.Lock()

def check_internet(timeout=2.5):
    """Verifica rapida della connettività Internet / Wi-Fi."""
    import urllib.request
    try:
        urllib.request.urlopen("https://www.google.com", timeout=timeout)
        return True
    except Exception:
        try:
            urllib.request.urlopen("https://huggingface.co", timeout=timeout)
            return True
        except Exception:
            return False

def get_installed_models():
    """Scansiona i modelli installati nella cache di WSL2 e LM Studio."""
    installed = []

    # 1. HuggingFace Cache in WSL2
    if WSL_HF_CACHE_WIN.exists():
        try:
            for item in WSL_HF_CACHE_WIN.iterdir():
                if item.is_dir() and item.name.startswith("models--"):
                    # models--Qwen--Qwen2.5-7B-Instruct-AWQ -> Qwen/Qwen2.5-7B-Instruct-AWQ
                    parts = item.name.replace("models--", "").split("--")
                    repo_id = "/".join(parts)

                    # Calcola dimensione cartella
                    total_bytes = 0
                    try:
                        for f in item.rglob("*"):
                            if f.is_file():
                                total_bytes += f.stat().st_size
                    except Exception:
                        pass

                    size_gb = round(total_bytes / (1024 ** 3), 2)
                    installed.append({
                        "id": repo_id,
                        "folder_name": item.name,
                        "source": "vllm_wsl",
                        "size_gb": size_gb,
                        "path": str(item)
                    })
        except Exception as e:
            print(f"Errore scansione WSL cache: {e}")

    # 2. LM Studio models
    if LMSTUDIO_MODELS_WIN.exists():
        try:
            for f in LMSTUDIO_MODELS_WIN.rglob("*.gguf"):
                size_gb = round(f.stat().st_size / (1024 ** 3), 2)
                installed.append({
                    "id": f.stem,
                    "folder_name": f.name,
                    "source": "lmstudio",
                    "size_gb": size_gb,
                    "path": str(f)
                })
        except Exception as e:
            print(f"Errore scansione LM Studio models: {e}")

    return installed

def run_download_job(model_repo):
    global current_job
    with job_lock:
        current_job["status"] = "downloading"
        current_job["model"] = model_repo
        current_job["log"] = "Inizializzazione download in ambiente WSL2...\n"
        current_job["start_time"] = time.time()
        current_job["error"] = None

    try:
        # Esecuzione in WSL2 con huggingface-cli
        cmd = [
            "wsl.exe", "-d", "Ubuntu", "bash", "-c",
            f"export NO_PROXY='localhost,127.0.0.1,::1,192.168.1.0/24' && "
            f"source /home/admin_ubuntu/vllm-env/bin/activate && "
            f"huggingface-cli download '{model_repo}' --local-dir-use-symlinks True"
        ]

        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )

        for line in process.stdout:
            with job_lock:
                current_job["log"] += line

        process.wait()

        with job_lock:
            if process.returncode == 0:
                current_job["status"] = "completed"
                current_job["log"] += "\n[OK] Download e installazione completati con successo!"
            else:
                current_job["status"] = "error"
                current_job["error"] = f"Processo terminato con codice {process.returncode}"
    except Exception as e:
        with job_lock:
            current_job["status"] = "error"
            current_job["error"] = str(e)
            current_job["log"] += f"\n[ERRORE] {e}"

def delete_model(model_id):
    """Elimina il modello specificato dalla cache per liberare spazio su disco."""
    # Converti ID modello nel nome cartella HF: Qwen/Qwen2.5-7B-Instruct-AWQ -> models--Qwen--Qwen2.5-7B-Instruct-AWQ
    folder_name = "models--" + model_id.replace("/", "--")
    target_path = WSL_HF_CACHE_WIN / folder_name

    if target_path.exists():
        try:
            # Elimina da Windows tramite UNC o comando WSL
            cmd = ["wsl.exe", "-d", "Ubuntu", "bash", "-c", f"rm -rf ~/.cache/huggingface/hub/{folder_name}"]
            res = subprocess.run(cmd, capture_output=True, text=True)
            if res.returncode == 0:
                return True, "Modello eliminato con successo dalla cache WSL2"
            else:
                # Prova fallback Python rmtree
                shutil.rmtree(target_path, ignore_errors=True)
                return True, "Modello eliminato tramite filesystem Windows"
        except Exception as e:
            return False, str(e)

    # Controlla se è in LM Studio
    if LMSTUDIO_MODELS_WIN.exists():
        for f in LMSTUDIO_MODELS_WIN.rglob(f"*{model_id}*.gguf"):
            try:
                f.unlink()
                return True, f"File GGUF rimosso da LM Studio: {f.name}"
            except Exception as e:
                return False, str(e)

    return False, "Cartella o file del modello non trovato su disco"


class ModelManagerHandler(http.server.BaseHTTPRequestHandler):
    def end_headers(self):
        # Aggiungi intestazioni CORS
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == "/api/status":
            has_wifi = check_internet()
            installed = get_installed_models()
            data = {
                "online": True,
                "internet": has_wifi,
                "installed_count": len(installed)
            }
            self._send_json(200, data)

        elif path == "/api/models":
            installed = get_installed_models()
            has_wifi = check_internet()
            data = {
                "installed": installed,
                "internet": has_wifi
            }
            self._send_json(200, data)

        elif path == "/api/job":
            with job_lock:
                self._send_json(200, current_job)

        else:
            self._send_json(404, {"error": "Endpoint non trovato"})

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8") if length > 0 else "{}"
        try:
            payload = json.loads(body)
        except Exception:
            payload = {}

        if path == "/api/install":
            model = payload.get("model")
            if not model:
                self._send_json(400, {"error": "Parametro 'model' mancante"})
                return

            # Controllo connessione Internet / Wi-Fi
            if not check_internet():
                self._send_json(400, {
                    "error": "Nessuna connessione Internet / Wi-Fi attiva. Connettiti a una rete per scaricare modelli."
                })
                return

            # Controlla se un job è già in corso
            with job_lock:
                if current_job["status"] == "downloading":
                    self._send_json(409, {
                        "error": f"Download già in corso per {current_job['model']}. Attendi il completamento."
                    })
                    return

            # Avvia download in thread separato
            t = threading.Thread(target=run_download_job, args=(model,), daemon=True)
            t.start()

            self._send_json(200, {
                "message": f"Download avviato per {model}",
                "model": model
            })

        elif path == "/api/delete":
            model = payload.get("model")
            if not model:
                self._send_json(400, {"error": "Parametro 'model' mancante"})
                return

            success, msg = delete_model(model)
            if success:
                self._send_json(200, {"success": True, "message": msg, "model": model})
            else:
                self._send_json(400, {"success": False, "error": msg, "model": model})

        else:
            self._send_json(404, {"error": "Endpoint non trovato"})

    def _send_json(self, status_code, data):
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data, indent=2).encode("utf-8"))

    def log_message(self, format, *args):
        # Silenzia i log standard per non inquinare la console
        pass


def run_server():
    server_address = (HOST, PORT)
    httpd = http.server.HTTPServer(server_address, ModelManagerHandler)
    print(f"vLLM Studio Model Manager Server attivo su http://{HOST}:{PORT}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nArresto server.")
        httpd.server_close()


if __name__ == "__main__":
    run_server()
