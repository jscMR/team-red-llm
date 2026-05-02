# VRAM Guide

> "What model can I actually run on my GPU?"

If you have an AMD card and you've asked this question, you're not alone. Here are the answers.

---

## Quick lookup

Find your VRAM, pick a row. Tok/s numbers are **real measurements** from [our benchmarks](benchmarks/results.csv) — not estimates.

### 8 GB VRAM
Examples: RX 7600, RX 6600 XT

| Model | Quant | Active / Total | Tok/s gen | Mode |
|-------|-------|---------------|-----------|------|
| Qwen 2.5 7B | Q5_K_M | — | ~60-80 ⚠️ | Full GPU |
| Phi-4 14B | Q4_K_M | — | ~30-50 ⚠️ | Full GPU |
| Llama 3.1 8B | Q4_K_M | — | ~50-70 ⚠️ | Full GPU |
| Gemma 3 4B | Q6_K | — | ~100+ ⚠️ | Full GPU |

> ⚠️ = estimated from similar arch, not yet benchmarked. [Submit yours](CONTRIBUTING.md).

### 12 GB VRAM
Examples: RX 7700 XT, RX 6750 XT

| Model | Quant | Active / Total | Tok/s gen | Mode |
|-------|-------|---------------|-----------|------|
| Mistral Small 22B | Q4_K_M | — | ~30-50 ⚠️ | Full GPU |
| Qwen 2.5 14B | Q5_K_M | — | ~40-60 ⚠️ | Full GPU |
| Llama 3.1 8B | Q8_0 | — | ~50-80 ⚠️ | Full GPU |
| Command R 35B | Q3_K_M | — | ~15-25 ⚠️ | MoE offload |

### 16 GB VRAM
Examples: RX 7800 XT, RX 7900 GRE, RX 6800 XT

| Model | Quant | Active / Total | Tok/s gen | Mode |
|-------|-------|---------------|-----------|------|
| **Moonlight 16B A3B** | Q6_K | 3B/16B | **100.2** ✅ | Full GPU |
| **Gemma 4 26B A4B** | UD-Q4_K_M | 4B/26B | **31.0** ✅ | MoE offload (`-ncmoe 6`) |
| **Qwen 3.6 35B A3B** | Q4_K_S | 3B/35B | **22.7** ✅ | MoE offload (`-ncmoe 32`) |
| Gemma 4 26B | UD-Q6_K | 4B/26B | 17.3 ✅ | MoE offload (`-ncmoe 16`) |
| Qwen 2.5 14B | Q6_K | — | ~60-90 ⚠️ | Full GPU |

> ✅ = real benchmarks on RX 7900 GRE.

### 20 GB VRAM
Examples: RX 7900 XT

| Model | Quant | Active / Total | Tok/s gen | Mode |
|-------|-------|---------------|-----------|------|
| Qwen 2.5 32B | Q4_K_M | — | ~25-45 ⚠️ | Full GPU |
| Mixtral 8x7B | Q5_K_M | 13B/47B | ~30-50 ⚠️ | Full GPU |
| DeepSeek V2 Lite | Q6_K | 2.4B/16B | ~100+ ⚠️ | Full GPU |

### 24 GB VRAM
Examples: RX 7900 XTX

| Model | Quant | Active / Total | Tok/s gen | Mode |
|-------|-------|---------------|-----------|------|
| Qwen 2.5 32B | Q5_K_M | — | ~30-60 ⚠️ | Full GPU |
| Mistral Small 3 22B | Q6_K | — | ~40-70 ⚠️ | Full GPU |
| Llama 3.1 70B | Q3_K_M | — | ~10-20 ⚠️ | Full GPU |
| Command R+ 104B | Q4_K_M | — | ~5-10 ⚠️ | MoE offload |

> ⚠️ = estimated or from community reports. PR your real numbers.

---

## What if my card isn't listed?

Rough heuristic: same VRAM ≈ same model capacity. A 7800 XT (16GB) and a 7900 GRE (16GB) can run the same models — the GRE is ~15-20% faster due to higher memory bandwidth.

Use [llmfit](https://github.com/AlexsJones/llmfit) to get model recommendations tailored to your exact hardware.

---

## Key concepts

### Full GPU vs MoE offload

- **Full GPU** — Model weights + KV cache fit entirely in VRAM. Fast, limited by memory bandwidth (~576 GB/s on 7900 GRE). Use `-ngl 99`.
- **MoE offload** — Model too big for VRAM. FFN expert weights of first N layers stay in CPU RAM via `-ncmoe N`. Much slower (limited by DDR5 ~80 GB/s) but enables 30B+ models on 16GB cards. See [COOKBOOK.md § MoE offloading](COOKBOOK.md#moe-offloading-with--ncmoe).

### Quantization impact

Lower quant = less VRAM but lower quality:

| Quant | VRAM multiplier | Quality |
|-------|----------------|---------|
| Q8_0 | 1.0× params in GB | Reference |
| Q6_K | 0.75× | Near lossless |
| Q5_K_M | 0.67× | Excellent |
| Q4_K_M | 0.50× | Very good |
| Q4_K_S | 0.47× | Good |
| Q3_K_M | 0.38× | Usable |

For 16B params at Q4_K_M: ~8 GB VRAM. At Q6_K: ~12 GB VRAM.

---

## Pro tip: check before downloading

Use `llmfit` to check if a model fits your GPU before spending 20 minutes downloading it.

```bash
# Install
curl -fsSL https://llmfit.axjns.dev/install.sh | sh

# Run (auto-detects your GPU)
llmfit
```

Then cross-reference with our [benchmarks](benchmarks/results.csv) for real tok/s numbers with the exact flags.
