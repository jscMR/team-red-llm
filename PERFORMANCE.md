# Performance Guide

> "My 7900 XTX has 24GB — why is it so slow?"

You're not the first. AMD GPUs need specific tuning to reach their potential. Here's what to check.

---

## The performance checklist

Run through these in order. Most AMD users leave 30-50% performance on the table with stock settings.

### 1. Are you actually using the GPU?

```bash
# Check GPU utilization during inference
watch -n 1 rocm-smi --showuse --showmemuse
```

- **GPU at 90-100%, VRAM filled** → ✅ GPU is working. Proceed to step 2.
- **GPU at 0-10%, CPU at 400-500%** → ❌ Silent CPU fallback. See [TROUBLESHOOTING.md § CPU-only fallback](TROUBLESHOOTING.md#cpu-only-fallback-diagnosis).
- **GPU at 50-70%** → ⚠️ Bottleneck elsewhere. Check step 4.

### 2. Are all layers offloaded?

Startup log must show:
```
load_tensors: offloaded 32/32 layers to GPU
load_tensors:   ROCm0 model buffer size = 4213.28 MiB
```

Not:
```
load_tensors:   CPU_Mapped model buffer size = 4213.28 MiB  ← BAD
```

If layers aren't offloading:
- `-ngl 99` flag is missing
- Quant not supported on ROCm (MXFP4, AWQ, etc.)
- iGPU clash — add `HIP_VISIBLE_DEVICES=0`

### 3. Are the flags right?

The flags that make a **2-3× difference** on AMD:

```bash
-fa on                    # Flash Attention — enables KV cache quantization
-ctk q8_0 -ctv q8_0       # KV cache quantization — 4× less VRAM for context
--jinja                   # Use model's built-in chat template
```

Without `-fa on` and `-ctk/ctv`, a 32K context burns 1.2 GB — 4× more than needed.

### 4. Is the CPU the bottleneck?

For MoE models with `-ncmoe`, the bottleneck is **DDR5 bandwidth**, not GPU compute.

```
Expected speeds:
  Full GPU:          100-200 tok/s  (RX 7900 GRE, 576 GB/s bandwidth)
  MoE with -ncmoe:   15-35 tok/s    (DDR5-6000, ~80 GB/s bandwidth)
```

If you're getting <10 tok/s on MoE:
- Increase `-ncmoe` (fewer experts in VRAM = less DDR traffic per token)
- Decrease context (`-c 8192` instead of `-c 32768`)
- Limit CPU threads: `-t 4` (MoE offload is memory-bound, not CPU-bound)

### 5. Power limit tuning

At stock 260W (RX 7900 GRE), sustained inference is loud and hot. Dropping the power limit loses ~5% performance for much quieter operation:

```bash
# Set power limit to 220W (85% of stock)
rocm-smi --setpoweroverdrive 220

# Reset to stock
rocm-smi --resetpoweroverdrive

# Check current limit
rocm-smi --showpower
```

Approximate impact:

| Power limit | Tok/s impact | Noise |
|-------------|-------------|-------|
| 260W (stock) | 100% | Jet engine |
| 220W | ~95% | Quiet |
| 180W | ~85% | Silent |

### 6. Multi-GPU: the iGPU is NOT your friend

If you have a Ryzen 7000/8000, the integrated GPU (`gfx1036`) will be detected as a second device. llama.cpp tries to split the model — usually crashing or slowing down.

```bash
# Always force the dedicated GPU
HIP_VISIBLE_DEVICES=0 llama-server --model ... -ngl 99
```

If you have two dedicated AMD GPUs and actually want to split:
```bash
# Build with both targets
-DAMDGPU_TARGETS="gfx1100;gfx1100"

# Control the split
--tensor-split 0.6,0.4
```

---

## Expected performance by GPU tier

Based on community data. Your numbers will vary with model, quant, and flags.

| GPU | VRAM | Bandwidth | Dense 7B Q4 | MoE 16B Q6 | MoE 35B Q4 (-ncmoe) |
|-----|------|-----------|-------------|------------|---------------------|
| RX 7600 | 8 GB | 288 GB/s | ~60-80 ⚠️ | ❌ | ❌ |
| RX 7700 XT | 12 GB | 432 GB/s | ~70-100 ⚠️ | N/A | N/A |
| RX 7800 XT | 16 GB | 624 GB/s | ~80-120 ⚠️ | ~90-110 ⚠️ | ~25-35 ⚠️ |
| RX 7900 GRE | 16 GB | 576 GB/s | ~60-90 ⚠️ | **100.2** ✅ | **22.7** ✅ |
| RX 7900 XT | 20 GB | 800 GB/s | ~90-140 ⚠️ | ~120-160 ⚠️ | ~30-45 ⚠️ |
| RX 7900 XTX | 24 GB | 960 GB/s | ~110-170 ⚠️ | ~140-190 ⚠️ | ~35-55 ⚠️ |
| RX 9070 XT | 16 GB | 640 GB/s | ~80-120 ⚠️ | ~90-130 ⚠️ | ~25-40 ⚠️ |

> ✅ = real benchmarks. ⚠️ = estimates or from similar cards. [Add your numbers](CONTRIBUTING.md).

### NVIDIA comparison (for context)

| AMD | Rough NVIDIA equivalent (inference) |
|-----|-------------------------------------|
| RX 7900 GRE (16GB) | RTX 4070 Ti Super (16GB) |
| RX 7900 XT (20GB) | RTX 3090 (24GB) |
| RX 7900 XTX (24GB) | RTX 4090 (24GB) in VRAM, RTX 4080 in tok/s |

AMD typically matches or exceeds NVIDIA in VRAM/$, but trails in raw tok/s due to immature ROCm optimizations.

---

## Benchmarking your setup

Don't guess — measure.

```bash
# Standardized benchmark
llama-bench -m model.gguf -p 512 -n 128 -ngl 99

# For MoE models
llama-bench -m model.gguf -p 512 -n 128 -ngl 99 -ncmoe 32

# Submit your results
# PR to benchmarks/results.csv or open an issue with the benchmark template
```

See [benchmarks/submit.md](benchmarks/submit.md) for the submission format.

---

## Quick reference: optimal flags

Copy-paste for dense models:
```bash
HIP_VISIBLE_DEVICES=0 llama-server \
  --model model.gguf \
  --port 8001 \
  -c 32768 \
  -ngl 99 \
  -fa on \
  -ctk q8_0 -ctv q8_0 \
  --jinja
```

Copy-paste for MoE models that don't fit in VRAM:
```bash
HIP_VISIBLE_DEVICES=0 llama-server \
  --model model.gguf \
  --port 8001 \
  -c 32768 \
  -ngl 99 \
  -ncmoe 32 \
  -fa on \
  -ctk q8_0 -ctv q8_0 \
  --jinja
```

Tuning `-ncmoe`:
- Start with `-ncmoe 32` on 16GB cards
- If OOM: increase by 8
- If you have headroom (>2GB free): decrease by 4

---

## Still slow?

Open an issue with:
- GPU model + gfx code
- Full startup log from llama-server
- `llama-bench` output
- `rocm-smi` output during inference

We'll help you diagnose.
