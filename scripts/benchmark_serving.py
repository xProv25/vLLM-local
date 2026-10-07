#!/usr/bin/env python3
"""
Distributed Inference Benchmark Tool (`benchmark_serving`)
Designed for Phase 2 Cluster Evaluation (Qwen2.5-32B-Instruct-AWQ across 2 Nodes).
Measures:
- TTFT (Time To First Token)
- ITL (Inter-Token Latency)
- Generation Throughput (tokens/s)
- Concurrent System Throughput (tokens/s)
"""

import argparse
import asyncio
import json
import os
import statistics
import sys
import time
from typing import Any, Dict, List, Optional
import urllib.request
import urllib.error

# Ensure local cluster IPs bypass any corporate/WSL HTTP proxy
os.environ["NO_PROXY"] = "localhost,127.0.0.1,192.168.1.100,192.168.1.101,192.168.1.0/24"
os.environ["no_proxy"] = "localhost,127.0.0.1,192.168.1.100,192.168.1.101,192.168.1.0/24"

try:
    from openai import OpenAI, AsyncOpenAI
except ImportError:
    OpenAI = None
    AsyncOpenAI = None


def check_health(base_url: str, api_key: str) -> Optional[List[str]]:
    url = f"{base_url.rstrip('/')}/v1/models"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {api_key}"})
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            if resp.status == 200:
                data = json.loads(resp.read().decode("utf-8"))
                return [m.get("id") for m in data.get("data", [])]
    except Exception as e:
        print(f"[-] Health check failed ({url}): {e}")
        return None
    return None


def run_single_stream_benchmark(
    base_url: str,
    api_key: str,
    model: str,
    prompt: str,
    max_tokens: int,
    temperature: float,
) -> Dict[str, Any]:
    if not OpenAI:
        raise RuntimeError("openai package is required ('pip install openai')")

    client = OpenAI(base_url=f"{base_url.rstrip('/')}/v1", api_key=api_key)

    print(f"\n[+] Executing Single Request Streaming Test...")
    print(f"    Model:      {model}")
    print(f"    Max Tokens: {max_tokens}")
    print(f"    Prompt:     {prompt!r}\n")

    start_time = time.perf_counter()
    first_token_time = None
    token_timestamps = []
    generated_text = []

    stream = client.chat.completions.create(
        model=model,
        messages=[{"role": "user", "content": prompt}],
        max_tokens=max_tokens,
        temperature=temperature,
        stream=True,
    )

    for chunk in stream:
        delta = chunk.choices[0].delta.content if chunk.choices else ""
        if delta:
            now = time.perf_counter()
            if first_token_time is None:
                first_token_time = now
            token_timestamps.append(now)
            generated_text.append(delta)
            sys.stdout.write(delta)
            sys.stdout.flush()

    end_time = time.perf_counter()
    print("\n")

    num_tokens = len(token_timestamps)
    total_time = end_time - start_time
    ttft_ms = (first_token_time - start_time) * 1000 if first_token_time else total_time * 1000
    gen_time = (end_time - first_token_time) if first_token_time else total_time
    tps = (num_tokens / gen_time) if gen_time > 0 else 0.0

    itls = []
    if len(token_timestamps) > 1:
        itls = [
            (token_timestamps[i] - token_timestamps[i - 1]) * 1000
            for i in range(1, len(token_timestamps))
        ]

    mean_itl = statistics.mean(itls) if itls else 0.0
    median_itl = statistics.median(itls) if itls else 0.0
    p95_itl = statistics.quantiles(itls, n=20)[18] if len(itls) >= 20 else mean_itl

    return {
        "tokens": num_tokens,
        "total_latency_s": round(total_time, 4),
        "ttft_ms": round(ttft_ms, 2),
        "tps": round(tps, 2),
        "mean_itl_ms": round(mean_itl, 2),
        "median_itl_ms": round(median_itl, 2),
        "p95_itl_ms": round(p95_itl, 2),
        "text": "".join(generated_text),
    }


async def _concurrent_worker(
    client: Any,
    model: str,
    prompt: str,
    max_tokens: int,
    req_id: int,
) -> Dict[str, Any]:
    start = time.perf_counter()
    first_tok = None
    token_count = 0
    try:
        stream = await client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=max_tokens,
            temperature=0.7,
            stream=True,
        )
        async for chunk in stream:
            delta = chunk.choices[0].delta.content if chunk.choices else ""
            if delta:
                if first_tok is None:
                    first_tok = time.perf_counter()
                token_count += 1
        end = time.perf_counter()
        dur = end - start
        ttft = (first_tok - start) * 1000 if first_tok else dur * 1000
        return {
            "req_id": req_id,
            "success": True,
            "tokens": token_count,
            "duration": dur,
            "ttft_ms": ttft,
        }
    except Exception as exc:
        return {
            "req_id": req_id,
            "success": False,
            "tokens": 0,
            "duration": time.perf_counter() - start,
            "ttft_ms": 0.0,
            "error": str(exc),
        }


async def run_concurrency_test(
    base_url: str,
    api_key: str,
    model: str,
    concurrency: int,
    prompt: str,
    max_tokens: int,
) -> None:
    if not AsyncOpenAI:
        raise RuntimeError("openai package required.")

    client = AsyncOpenAI(base_url=f"{base_url.rstrip('/')}/v1", api_key=api_key)
    print(f"\n[+] Running Concurrency Load Test (Concurrency: {concurrency})...")

    wall_start = time.perf_counter()
    tasks = [
        _concurrent_worker(client, model, prompt, max_tokens, i + 1)
        for i in range(concurrency)
    ]
    results = await asyncio.gather(*tasks)
    wall_duration = time.perf_counter() - wall_start

    successful = [r for r in results if r["success"]]
    total_tokens = sum(r["tokens"] for r in successful)
    system_tps = total_tokens / wall_duration if wall_duration > 0 else 0.0
    avg_ttft = statistics.mean([r["ttft_ms"] for r in successful]) if successful else 0.0
    avg_latency = statistics.mean([r["duration"] for r in successful]) if successful else 0.0

    print("=" * 65)
    print(" DISTRIBUTED CLUSTER CONCURRENCY BENCHMARK RESULTS")
    print("=" * 65)
    print(f" Concurrency Level:       {concurrency}")
    print(f" Successful Requests:     {len(successful)} / {len(results)}")
    print(f" Wall Clock Time:         {wall_duration:.2f} s")
    print(f" Total Tokens Generated:  {total_tokens}")
    print(f" System Throughput:       {system_tps:.2f} tokens/s")
    print(f" Average TTFT:            {avg_ttft:.2f} ms")
    print(f" Average Latency / Req:   {avg_latency:.2f} s")
    print("=" * 65)


def main():
    parser = argparse.ArgumentParser(description="Distributed vLLM Inference Benchmark Tool")
    parser.add_argument("--url", default="http://localhost:8000", help="vLLM API endpoint URL")
    parser.add_argument("--api-key", default="vllm-local-token", help="vLLM API key")
    parser.add_argument("--model", default="Qwen/Qwen2.5-32B-Instruct-AWQ", help="Model name")
    parser.add_argument(
        "--prompt",
        default="Compare Gigabit Ethernet interconnect with NVLink/InfiniBand for distributed Pipeline Parallelism in 3 concise bullet points.",
        help="Benchmark prompt",
    )
    parser.add_argument("--max-tokens", type=int, default=128, help="Max generation tokens")
    parser.add_argument("--temperature", type=float, default=0.7, help="Temperature")
    parser.add_argument("--concurrency", type=int, default=1, help="Parallel client requests")
    parser.add_argument("--warmup", action="store_true", help="Perform 1 warmup request before benchmarking")

    args = parser.parse_args()

    print("==========================================================")
    print(" vLLM Distributed Serving Benchmark (benchmark_serving)")
    print("==========================================================")
    print(f" Target Endpoint: {args.url}")

    available_models = check_health(args.url, args.api_key)
    if not available_models:
        print(f"[-] Cannot connect to {args.url}. Make sure vLLM cluster server is running.")
        sys.exit(1)

    print(f"[+] Cluster Online! Models served: {available_models}")

    target_model = args.model
    if target_model not in available_models and available_models:
        print(f"[!] Target model '{args.model}' not found in served models.")
        print(f"[!] Selecting active model: '{available_models[0]}'")
        target_model = available_models[0]

    if args.warmup:
        print("[+] Performing warmup request...")
        try:
            client = OpenAI(base_url=f"{args.url.rstrip('/')}/v1", api_key=args.api_key)
            client.chat.completions.create(
                model=target_model,
                messages=[{"role": "user", "content": "Hi"}],
                max_tokens=8,
            )
            print("[+] Warmup complete.")
        except Exception as e:
            print(f"[!] Warmup failed: {e}")

    if args.concurrency > 1:
        asyncio.run(
            run_concurrency_test(
                base_url=args.url,
                api_key=args.api_key,
                model=target_model,
                concurrency=args.concurrency,
                prompt=args.prompt,
                max_tokens=args.max_tokens,
            )
        )
    else:
        res = run_single_stream_benchmark(
            base_url=args.url,
            api_key=args.api_key,
            model=target_model,
            prompt=args.prompt,
            max_tokens=args.max_tokens,
            temperature=args.temperature,
        )
        print("=" * 65)
        print(" SINGLE STREAM INFERENCE BENCHMARK RESULTS")
        print("=" * 65)
        print(f" Tokens Generated:          {res['tokens']}")
        print(f" TTFT (Time to First Token): {res['ttft_ms']} ms")
        print(f" Mean Inter-Token Latency:   {res['mean_itl_ms']} ms")
        print(f" Median ITL:                 {res['median_itl_ms']} ms")
        print(f" P95 ITL:                    {res['p95_itl_ms']} ms")
        print(f" Generation Throughput:      {res['tps']} tokens/s")
        print(f" Total Wall Latency:         {res['total_latency_s']} s")
        print("=" * 65)


if __name__ == "__main__":
    main()
