# AMD Radeon RX 7900 GRE (16 GB)

## Specs

| | |
|---|---|
| Architecture | RDNA 3 |
| GFX code | `gfx1100` |
| VRAM | 16 GB GDDR6 |
| Memory bandwidth | 576 GB/s |
| Compute units | 80 |
| TBP | 260 W |
| MSRP (used) | ~400-500 € |

## ROCm support

Mature. Treat it as the equivalent of an "RTX 4070 Ti" in the AMD line for inference purposes — supported by every modern llama.cpp/ROCm release.

## Sweet-spot models

Models that fit fully in VRAM (no CPU offload, max throughput):

- **Dense up to 14B** at Q5_K_M / Q6_K (12-13 GB)
- **MoE up to 30B total / 3B active** at Q4-Q6 (e.g. Moonlight-16B-A3B, gpt-oss-20b if MXFP4 ever lands on ROCm)
- **DeepSeek-V2-Lite (16B/2.4B active)** Q6_K — excellent speed/quality

Models that need `-ncmoe` offloading:

- **Qwen3.6-35B-A3B** with `-ncmoe 32` at Q4_K_S
- **Mixtral-8x7B** with `-ncmoe 16-24`

## Recommended `llama-server` baseline

```bash
HIP_VISIBLE_DEVICES=0 llama-server \
  --model ~/models/<model>.gguf \
  --port 8001 \
  -c 32768 \
  -ngl 99 \
  -fa on \
  -ctk q8_0 -ctv q8_0 \
  --jinja
```

## Watch out for

- **Ryzen iGPU clash** — if you're paired with a Ryzen 7000/8000 with iGPU (`gfx1036`/`gfx1103`), always set `HIP_VISIBLE_DEVICES=0`. See [COOKBOOK § Multi-GPU](../COOKBOOK.md#multi-gpu-and-the-igpu-trap).
- **Power limit** — at 260W TBP, sustained inference is loud. `rocm-smi --setpoweroverdrive 220` knocks ~5% off tok/s for much quieter operation.
- **No ECC** — consumer card. For 24/7 production, look at MI series.

## Confirmed working

See [benchmarks/results.csv](../benchmarks/results.csv) for tested models.
