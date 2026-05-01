# Moonlight-16B-A3B-Instruct

MoE model from Moonshot AI. 16B total params, ~3B active per token. Uses DeepSeek-V2 architecture under the hood (`general.architecture: deepseek2` in GGUF metadata).

## Why it's good for AMD homelabs

- **Fits fully in VRAM** at Q6_K on 16GB cards (no `-ncmoe` needed)
- **Standard quants only** — no MXFP4/AWQ traps
- **DeepSeek-V2 arch is well-supported** by ROCm in modern llama.cpp builds
- **Fast generation** — ~100 tok/s on RX 7900 GRE

## Recommended GGUF source

[`gabriellarson/Moonlight-16B-A3B-Instruct-GGUF`](https://huggingface.co/gabriellarson/Moonlight-16B-A3B-Instruct-GGUF)

Avoid the `MXFP4_MOE` variant — that quant doesn't run on ROCm yet (CPU fallback).

## Working `llama-server` config

```bash
HIP_VISIBLE_DEVICES=0 llama-server \
  --model ~/models/Moonlight-16B-A3B-Instruct-Q6_K.gguf \
  --port 8001 \
  --alias moonlight-16b-a3b \
  -c 32768 \
  -n 4096 \
  -ngl 99 \
  -fa on \
  -ctk q8_0 -ctv q8_0 \
  --jinja
```

## Verified results

| GPU | Quant | Gen tok/s | Prompt tok/s | Context | Build |
|---|---|---|---|---|---|
| RX 7900 GRE | Q6_K | 100.2 | 188.1 | 32K | b8999 |

## Use cases

- **Agent delegation / tool calling** — fast enough for synchronous tool use
- **General chat** — quality is decent but not at the level of denser 30B+ models
- **Routing / classification** — overkill but cheap to run

## Known issues

- Native context is only 8K — extending beyond 32K hasn't been tested on this build
- Chat template needs `--jinja` flag, default template doesn't apply correctly
