#!/usr/bin/env python3
"""
Environment & Hardware Verification Script for vLLM
"""
import sys
import platform

print("=" * 60)
print(" vLLM & PyTorch Hardware Verification")
print("=" * 60)
print(f"Python Executable: {sys.executable}")
print(f"Python Version:    {platform.python_version()}")
print(f"Platform:          {platform.platform()}")

try:
    import torch
    print(f"PyTorch Version:   {torch.__version__}")
    cuda_avail = torch.cuda.is_available()
    print(f"CUDA Available:    {cuda_avail}")
    if cuda_avail:
        print(f"CUDA Version:      {torch.version.cuda}")
        print(f"Device Count:      {torch.cuda.device_count()}")
        dev_name = torch.cuda.get_device_name(0)
        total_vram_gb = torch.cuda.get_device_properties(0).total_memory / (1024 ** 3)
        print(f"GPU 0 Name:        {dev_name}")
        print(f"GPU 0 VRAM:        {total_vram_gb:.2f} GB")
        
        # Test basic tensor allocation on GPU
        x = torch.randn(1000, 1000, device="cuda")
        y = torch.matmul(x, x)
        print(f"GPU Compute Test:  SUCCESS (Tensor matmul OK, allocated {torch.cuda.memory_allocated() / 1024**2:.2f} MB)")
    else:
        print("[-] WARNING: CUDA is NOT available to PyTorch!")
except ImportError as e:
    print(f"[-] PyTorch Import Error: {e}")

try:
    import vllm
    print(f"vLLM Version:      {vllm.__version__}")
    print("[+] vLLM imported successfully!")
except ImportError as e:
    print(f"[-] vLLM Import Error: {e}")

print("=" * 60)
