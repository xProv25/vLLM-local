#!/usr/bin/env python3
"""
Hotfix for Ray NVML UnicodeDecodeError on WSL2.
WSL2 NVIDIA driver sometimes returns non-UTF8 bytes for nvmlDeviceGetName,
causing Ray's accelerator manager to throw UnicodeDecodeError.
This script patches ray/_private/accelerators/nvidia_gpu.py and pynvml safely.
"""
import os
import sys

def patch_file(filepath: str, old_str: str, new_str: str) -> bool:
    if not os.path.exists(filepath):
        return False
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    if old_str in content:
        content = content.replace(old_str, new_str)
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"[+] Successfully patched: {filepath}")
        return True
    return False

def main():
    site_packages = [p for p in sys.path if "site-packages" in p]
    if not site_packages:
        print("[-] site-packages directory not found in sys.path")
        sys.exit(1)

    sp = site_packages[0]
    ray_nvidia = os.path.join(sp, "ray", "_private", "accelerators", "nvidia_gpu.py")
    patch_file(
        ray_nvidia,
        'device_name = device_name.decode("utf-8")',
        'device_name = device_name.decode("utf-8", errors="ignore")',
    )

    pynvml_path = os.path.join(sp, "pynvml.py")
    patch_file(
        pynvml_path,
        'return res.decode()',
        'return res.decode("utf-8", errors="ignore").strip("\\x00")',
    )
    print("[+] Ray & pynvml hotfixes applied successfully.")

if __name__ == "__main__":
    main()
