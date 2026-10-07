#!/usr/bin/env python3
"""
vLLM Benchmark & Validation Client
Supports OpenAI-compatible /v1/chat/completions and /v1/models endpoints.
Measures TTFT (Time To First Token), generation throughput (tokens/sec), and latency.
"""

import argparse
import asyncio
import json
import os
import sys
import time
from typing import Any, Dict, List, Optional
import urllib.request
import urllib.error

try:
    import aiohttp
except ImportError:
    aiohttp = None

try:
    from openai import OpenAI, AsyncOpenAI
except ImportError:
    OpenAI = None
    AsyncOpenAI = None


def check_server_health(base_url: str, api_key: str) -> Optional[Dict[str, Any]]:
    """Checks if vLLM server is responding and lists served models."""
    url = f"{base_url.rstrip('/')}/v1/models"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {api_key}"})
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.status == 200:
                data = json.loads(response.read().decode("utf-8"))
                return data
    except urllib.error.URLError as e:
        print(f"[-] Connection failed to {url}: {e}")
        return None
    return None


def run_sync_benchmark(
    base_url: str,
    api_key: str,
    model: str,
    prompt: str,
    max_tokens: int,
    temperature: float,
) -> Dict[str, Any]:
    """Runs a single streaming request and measures TTFT and TPS."""
    if not OpenAI:
        raise RuntimeError("openai python package is required. Run 'pip install openai'.")

    client = OpenAI(base_url=f"{base_url.rstrip('/')}/v1", api_key=api_key)

    messages = [
        {"role": "system", "content": "You are a helpful AI assistant. Give concise answers."},
        {"role": "user", "content": prompt},
    ]

    print(f"\n[+] Sending streaming prompt: {prompt!r}")
    print(f"[+] Model: {model} | Max Tokens: {max_tokens} | Temp: {temperature}\n")

    start_time = time.perf_counter()
    first_token_time = None
    chunks_text = []
    token_count = 0

    response = client.chat.completions.create(
        model=model,
        messages=messages,
        max_tokens=max_tokens,
        temperature=temperature,
        stream=True,
    )

    for chunk in response:
        delta = chunk.choices[0].delta.content if chunk.choices else ""
        if delta:
            if first_token_time is None:
                first_token_time = time.perf_counter()
            chunks_text.append(delta)
            token_count += 1
            sys.stdout.write(delta)
            sys.stdout.flush()

    end_time = time.perf_counter()
    print("\n")

    total_duration = end_time - start_time
    ttft = (first_token_time - start_time) if first_token_time else total_duration
    generation_duration = (end_time - first_token_time) if first_token_time else total_duration
    tps = (token_count / generation_duration) if generation_duration > 0 else 0.0

    return {
        "prompt": prompt,
        "token_count": token_count,
        "total_latency_sec": round(total_duration, 4),
        "ttft_ms": round(ttft * 1000, 2),
        "tokens_per_second": round(tps, 2),
        "response_text": "".join(chunks_text),
    }


async def _async_worker(
    client: Any,
    model: str,
    prompt: str,
    max_tokens: int,
    req_id: int,
) -> Dict[str, Any]:
    start_time = time.perf_counter()
    first_token_time = None
    token_count = 0

    try:
        response = await client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=max_tokens,
            temperature=0.7,
            stream=True,
        )
        async for chunk in response:
            delta = chunk.choices[0].delta.content if chunk.choices else ""
            if delta:
                if first_token_time is None:
                    first_token_time = time.perf_counter()
                token_count += 1

        end_time = time.perf_counter()
        total_time = end_time - start_time
        ttft = (first_token_time - start_time) if first_token_time else total_time
        gen_time = (end_time - first_token_time) if first_token_time else total_time
        tps = (token_count / gen_time) if gen_time > 0 else 0.0

        return {
            "req_id": req_id,
            "success": True,
            "tokens": token_count,
            "latency": total_time,
            "ttft_ms": ttft * 1000,
            "tps": tps,
        }
    except Exception as exc:
        return {
            "req_id": req_id,
            "success": False,
            "error": str(exc),
            "tokens": 0,
            "latency": time.perf_counter() - start_time,
            "ttft_ms": 0.0,
            "tps": 0.0,
        }


async def run_concurrent_benchmark(
    base_url: str,
    api_key: str,
    model: str,
    concurrency: int,
    prompt: str,
    max_tokens: int,
) -> None:
    if not AsyncOpenAI:
        raise RuntimeError("openai python package is required.")

    client = AsyncOpenAI(base_url=f"{base_url.rstrip('/')}/v1", api_key=api_key)
    print(f"\n[+] Running Concurrency Test: {concurrency} parallel requests...")

    overall_start = time.perf_counter()
    tasks = [
        _async_worker(client, model, prompt, max_tokens, i + 1)
        for i in range(concurrency)
    ]
    results = await asyncio.gather(*tasks)
    overall_time = time.perf_counter() - overall_start

    successful = [r for r in results if r["success"]]
    total_tokens = sum(r["tokens"] for r in successful)
    avg_ttft = sum(r["ttft_ms"] for r in successful) / len(successful) if successful else 0.0
    avg_latency = sum(r["latency"] for r in successful) / len(successful) if successful else 0.0
    system_tps = total_tokens / overall_time if overall_time > 0 else 0.0

    print("=" * 60)
    print(" CONCURRENCY BENCHMARK RESULTS")
    print("=" * 60)
    print(f" Requests:            {len(results)} (Success: {len(successful)})")
    print(f" Concurrency Level:   {concurrency}")
    print(f" Total Wall Time:     {overall_time:.2f} s")
    print(f" Total Tokens Gen:    {total_tokens}")
    print(f" System Throughput:   {system_tps:.2f} tokens/s")
    print(f" Avg TTFT:            {avg_ttft:.2f} ms")
    print(f" Avg Latency/req:     {avg_latency:.2f} s")
    print("=" * 60)


def main():
    parser = argparse.ArgumentParser(description="vLLM OpenAI API Benchmark Client")
    parser.add_argument("--url", default="http://localhost:8000", help="vLLM base URL")
    parser.add_argument("--api-key", default="vllm-local-token", help="API key")
    parser.add_argument("--model", default="Qwen/Qwen2.5-32B-Instruct-AWQ", help="Model name")
    parser.add_argument(
        "--prompt",
        default="Explain the difference between Tensor Parallelism and Pipeline Parallelism in distributed LLM inference in 3 bullet points.",
        help="Test prompt",
    )
    parser.add_argument("--max-tokens", type=int, default=256, help="Max generated tokens")
    parser.add_argument("--temperature", type=float, default=0.7, help="Sampling temperature")
    parser.add_argument("--concurrency", type=int, default=1, help="Concurrent requests")
    parser.add_argument("--check-only", action="store_true", help="Only check server status")

    args = parser.parse_args()

    print("==========================================================")
    print(" vLLM Benchmark & Verification Tool")
    print("==========================================================")
    print(f" Target Endpoint: {args.url}")
    print(f" Checking server status...")

    models_info = check_server_health(args.url, args.api_key)
    if not models_info:
        print("[-] Server is not responding at given URL. Ensure vLLM is running.")
        sys.exit(1)

    served_models = [m.get("id") for m in models_info.get("data", [])]
    print(f"[+] Server is ONLINE! Available models: {served_models}")

    if args.check_only:
        return

    # If specified model not in served_models, use the first served model
    actual_model = args.model
    if actual_model not in served_models and served_models:
        print(f"[!] Warning: Specified model '{args.model}' not in served list.")
        print(f"[!] Auto-selecting active model: '{served_models[0]}'")
        actual_model = served_models[0]

    if args.concurrency > 1:
        asyncio.run(
            run_concurrent_benchmark(
                base_url=args.url,
                api_key=args.api_key,
                model=actual_model,
                concurrency=args.concurrency,
                prompt=args.prompt,
                max_tokens=args.max_tokens,
            )
        )
    else:
        res = run_sync_benchmark(
            base_url=args.url,
            api_key=args.api_key,
            model=actual_model,
            prompt=args.prompt,
            max_tokens=args.max_tokens,
            temperature=args.temperature,
        )
        print("=" * 60)
        print(" SINGLE REQUEST BENCHMARK RESULTS")
        print("=" * 60)
        print(f" Tokens Generated:    {res['token_count']}")
        print(f" TTFT (First Token):  {res['ttft_ms']} ms")
        print(f" Total Latency:       {res['total_latency_sec']} s")
        print(f" Throughput (TPS):    {res['tokens_per_second']} tokens/sec")
        print("=" * 60)


if __name__ == "__main__":
    main()
