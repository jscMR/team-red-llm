# Gemma-4 MoE family

Google's MoE variant of Gemma 4. The community-tested member is **Gemma-4-26B-A4B-it** — 26B total, 4B active per token, 128 experts.

## Why it's interesting on AMD

- **Standard quants work** — no NVFP4 trap (the original `bg-digitalservices/Gemma-4-26B-A4B-it-NVFP4` falls back to CPU on ROCm)
- **High active param count (4B vs ~3B)** — slightly better quality per token than Moonlight or Qwen3.6 MoE at the cost of speed
- **Mature instruction tuning** — Google's RLHF, good for general assistant tasks

## Recommended GGUF source

[`unsloth/gemma-4-26B-A4B-it-GGUF`](https://huggingface.co/unsloth/gemma-4-26B-A4B-it-GGUF) — most popular (3.5M downloads).

Avoid the `NVFP4` variant on AMD — fully CPU.

## Watch out: UD quants are bigger than plain quants

Unsloth's "UD" (Dynamic) quants use higher precision for sensitive layers. Real disk sizes:

| Quant label | Plain Q size | UD-Q size | Notes |
|---|---|---|---|
| Q4_K_M | ~14 GB | **~16 GB** | UD bumps it past 16GB VRAM line |
| Q6_K | ~17 GB | **~22 GB** | UD-Q6_K is heavy |

If `llmfit` says "fits in VRAM" based on plain Q6_K (~12 GB predicted), the UD variant won't actually fit and you'll need `-ncmoe`. Check the actual file size before launching.

## Working `llama-server` configs (RX 7900 GRE 16GB)

### Sweet spot: UD-Q4_K_M with light offload

```bash
HIP_VISIBLE_DEVICES=0 llama-server \
  --model ~/models/gemma-4-26B-A4B-it-UD-Q4_K_M.gguf \
  --port 8001 \
  --alias gemma-4-26b-a4b \
  -c 16384 \
  -ngl 99 \
  -ncmoe 6 \
  -fa on \
  -ctk q8_0 -ctv q8_0 \
  --jinja
```

**13.3 GB on GPU + 3.8 GB on CPU/RAM. Gen ~31 tok/s. Recommended baseline.**

### Higher quality: UD-Q6_K (slower)

```bash
HIP_VISIBLE_DEVICES=0 llama-server \
  --model ~/models/gemma-4-26B-A4B-it-UD-Q6_K.gguf \
  --port 8001 \
  -ngl 99 \
  -ncmoe 16 \   # -ncmoe 8 OOMs on 16GB
  -fa on \
  -ctk q8_0 -ctv q8_0 \
  --jinja
```

**11.6 GB GPU + 12.1 GB RAM. Gen ~17 tok/s.** Only worth it if quality matters more than speed.

## Verified results

| Quant | `-ncmoe` | Gen tok/s | Prompt tok/s | VRAM | RAM | Build |
|---|---|---|---|---|---|---|
| UD-Q4_K_M | 6 | **31.0** | 61.3 | 13.3 GB | 3.8 GB | b8999 |
| UD-Q6_K | 16 | 17.3 | 80.7 | 11.6 GB | 12.1 GB | b8999 |
| UD-Q6_K | 8 | OOM | OOM | 16.8 GB needed | — | b8999 |

## Memory pressure warning

When testing multiple GGUFs in one session, mmap'd page caches accumulate. With 30 GB system RAM:

- 3 large models in cache (~50+ GB total) → kernel starts compressing pages to ZRAM
- ZRAM compression uses CPU heavily
- llama-server is also using CPU heavily (especially with `-ncmoe`)
- Result: **system freeze during inference**

Mitigations:
1. `pkill llama-server` between tests, wait for memory release before launching next
2. Lower `zramSwap.memoryPercent` in NixOS config (default 50% is aggressive for inference workloads)
3. Watch with `btop` — if swap activates during inference, abort
