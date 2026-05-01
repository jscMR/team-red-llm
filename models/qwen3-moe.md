# Qwen3 MoE family

Qwen3 has multiple MoE variants. The community ones we've tested:

- **Qwen3.6-35B-A3B** — 35B total, 3B active. Sweet spot for 16GB VRAM with `-ncmoe`.
- **Qwen3-30B-A3B** — Earlier 30B/3B variant, similar profile.
- **Qwen3-Next-80B-A3B** — 80B total, AWQ only (vLLM territory, not llama.cpp).

## Architecture note

Qwen3 MoE models declare `general.architecture: qwen35moe` in their GGUF metadata. **You need llama.cpp build ≥ 8665** to load them. Older builds (including the `nixpkgs` `llama-cpp-rocm` package as of 2026-05) will fail with:

```
error loading model: error loading model architecture: unknown model architecture: 'qwen35moe'
```

Solution: build llama.cpp from source, see [COOKBOOK § Building llama.cpp with HIP](../COOKBOOK.md#building-llamacpp-with-hip).

## Recommended GGUF source

[`unsloth/Qwen3.6-35B-A3B-GGUF`](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF) — Unsloth Dynamic UD quants.

Pick `Q4_K_S` for 16GB VRAM cards (the model is too big to fit fully — needs `-ncmoe`).

## Working `llama-server` config (RX 7900 GRE 16GB)

```bash
HIP_VISIBLE_DEVICES=0 llama-server \
  --model ~/models/Qwen3.6-35B-A3B-UD-Q4_K_S.gguf \
  --port 8001 \
  --alias qwen3.6-35b-a3b \
  -c 65536 \
  -n 8192 \
  --no-context-shift \
  --temp 0.6 --top-p 0.95 --top-k 20 \
  --repeat-penalty 1.00 \
  -ngl 99 \
  -ncmoe 32 \
  -fa on \
  -ctk q8_0 -ctv q8_0 \
  --chat-template-kwargs '{"preserve_thinking": true}'
```

## Tuning `-ncmoe`

| `-ncmoe` | Behavior on 16GB |
|---|---|
| 16 | OOM likely |
| 24 | Tight, may OOM with long context |
| **32** | Recommended starting point |
| 48 | Fallback if OOM at 32 |
| 64+ | Slow (most experts in CPU RAM) |

## Sampling recipe (official Qwen3 thinking)

```
--temp 0.6 --top-p 0.95 --top-k 20 --repeat-penalty 1.00
```

For non-thinking mode, append `/no_think` to the user message. Quality drops noticeably but generation is much faster (skips the `<think>` block).

## Use cases

- **Heavy reasoning** — math, code, multi-step planning
- **Long context** — supports up to 200K+ at smaller `-ncmoe` values
- **Not for agent tool calls** — too slow due to thinking + offloading. Pair with a smaller dense model on a separate port for that.
