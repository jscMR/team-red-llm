# Troubleshooting

> "It worked yesterday!" — every AMD user ever.

Quick fixes for the 7 demons of ROCm inference. Start from the top and work down.

---

## Symptom / error → fix

| Symptom | Probable cause | Fix |
|---------|---------------|-----|
| `rocminfo` shows GPU but `clinfo` says 0 platforms | OpenCL ICD path not set | [OpenCL not detecting GPU](#opencl-not-detecting-gpu) |
| ROCm error: `invalid device function` | iGPU clash | [iGPU clash](#igpu-clash) |
| `no usable GPU found` on startup | Wrong build (GGML_HIPBLAS vs GGML_HIP) | [CPU-only build](#cpu-only-build) |
| All layers on CPU despite `-ngl 99` | Quant not supported on ROCm | [Unsupported quantization](#unsupported-quantization) |
| OOM even though VRAM should fit | MoE total params > VRAM | [MoE offloading](#moe-offloading) |
| Slow (<15 tok/s on >7B model) | Silent CPU fallback | [CPU-only fallback diagnosis](#cpu-only-fallback-diagnosis) |
| `rocminfo` doesn't see the GPU at all | Kernel driver / permissions | [GPU not detected at all](#gpu-not-detected-at-all) |

---

## OpenCL not detecting GPU

**Symptom:** `rocminfo` shows your GPU but `clinfo` reports `Number of platforms: 0`.

**Fix:** The OpenCL ICD loader doesn't know where ROCm lives.

```bash
# Find the amdocl64.icd file
find /opt/rocm* /nix/store -name "amdocl64.icd" 2>/dev/null

# Set the environment variable (add to your shell profile)
export OCL_ICD_VENDORS=/opt/rocm/etc/OpenCL/vendors

# On NixOS:
export OCL_ICD_VENDORS=$(find /nix/store -path "*/rocm-merged/etc/OpenCL/vendors" 2>/dev/null | head -1)
```

---

## iGPU clash

**Symptom:** 
```
ROCm error: invalid device function
  current device: 1, in function ggml_cuda_compute_forward
```

**Cause:** Ryzen 7000/8000 CPUs have integrated graphics (`gfx1036`). llama.cpp sees both GPUs and tries to split the model, but the iGPU kernels weren't compiled.

**Fix:** Limit to dedicated GPU only.

```bash
HIP_VISIBLE_DEVICES=0 llama-server --model ... -ngl 99
```

Verify:
```
ggml_cuda_init: found 1 ROCm devices (Total VRAM: 16368 MiB):
  Device 0: AMD Radeon RX 7900 GRE, gfx1100
```

---

## CPU-only build

**Symptom:** llama.cpp starts with `warning: no usable GPU found` or `ggml_cuda_init: no usable GPU`. `rocm-smi` shows the GPU correctly.

**Cause:** You used the deprecated cmake flag `-DGGML_HIPBLAS=ON`. cmake doesn't error — it builds a CPU-only binary.

**Fix:** Rebuild with `-DGGML_HIP=ON`. See [COOKBOOK.md § Building llama.cpp with HIP](COOKBOOK.md#building-llamacpp-with-hip).

Verify:
```bash
ls build/bin/*hip*           # Must show libggml-hip.so
./build/bin/llama-server --version 2>&1 | grep "ROCm devices"
```

---

## Unsupported quantization

**Symptom:** Model loads but inference is extremely slow. `rocm-smi` shows GPU at <10%.

**Cause:** Some quantization formats only work on CUDA. llama.cpp falls back to CPU silently.

| Format | ROCm support |
|--------|-------------|
| Q4_K_M, Q5_K_M, Q6_K, Q8_0 | ✅ Works |
| AWQ-4bit | ❌ CPU fallback |
| MXFP4 | ❌ CPU fallback |
| NVFP4 | ❌ CPU fallback |
| GPTQ-Int4 | ❌ CPU fallback |

**Fix:** Use a different GGUF repo with standard quants. Check tensor types after loading:
```
load_tensors: ROCm0 model buffer size = 13348 MiB  ← GOOD
load_tensors: CPU_Mapped model buffer size = 11073 MiB  ← BAD (all on CPU)
```

---

## MoE offloading

**Symptom:** OOM with `-ngl 99` on MoE models (Mixtral, DeepSeek-V2, Qwen3 MoE, Gemma 4).

**Cause:** MoE models have huge total parameters (e.g., Mixtral 8x7B = 47B total). They fit in RAM but not VRAM.

**Fix:** Use `-ncmoe N` to keep FFN expert weights of the first N layers in CPU RAM:

```bash
llama-server --model model.gguf -ngl 99 -ncmoe 32
```

See [COOKBOOK.md § MoE offloading](COOKBOOK.md#moe-offloading-with--ncmoe).

---

## CPU-only fallback diagnosis

**Symptom:** Low tok/s (<15 for 7B+ models), CPU at 400-500%, GPU at 0-7% on `rocm-smi`.

**Full checklist:**

1. **Is the binary GPU-capable?** `ls build/bin/*.so | grep hip`
2. **Does it detect the GPU?** Look for `ggml_cuda_init: found N ROCm devices`
3. **Did it offload layers?** Look for `offloaded N/N layers to GPU`
4. **Is the quant supported?** Check tensor type list for `mxfp4`, `awq`, etc.
5. **Multi-GPU crash?** Set `HIP_VISIBLE_DEVICES=0`
6. **Is rocm-smi happy?** Run `rocm-smi` — confirm VRAM reported correctly

If all passes and you're still slow, run a clean benchmark:
```bash
llama-bench -m model.gguf -p 512 -n 128 -ngl 99
```

---

## GPU not detected at all

**Symptom:** `rocminfo` returns no agents or only CPU agents.

**Troubleshooting steps:**

```bash
# 1. Is the amdgpu kernel module loaded?
lsmod | grep amdgpu

# 2. Does the render node exist?
ls /dev/dri/render* /dev/kfd

# 3. Are you in the right groups?
groups | grep -E "video|render"

# 4. Check kernel command line (GRUB)
cat /proc/cmdline | grep amdgpu

# 5. Try adding to kernel params (varies by distro):
# amdgpu.ppfeaturemask=0xffffffff amdgpu.dc=1
```

**If all else fails:** See [ROCm-SETUP.md](ROCm-SETUP.md) for clean installation per distro.

---

## Quick wins

Before deep-diving into any specific fix, run this:

```bash
# Verify hardware visible to ROCm
rocminfo | grep -E "Agent|Name:|gfx"

# Verify GPU utilization during inference
watch -n 1 rocm-smi --showuse --showmemuse

# Verify the binary actually offloads to GPU
llama-server --version 2>&1 | grep "ROCm devices"

# Clean benchmark
llama-bench -m your-model.gguf -p 512 -n 128 -ngl 99
```

---

## Still stuck?

Open an issue with the [rocm-gotcha template](.github/ISSUE_TEMPLATE/rocm-gotcha.yml). Include:
- GPU model + gfx code
- Distro + ROCm version
- llama.cpp build command + version
- Full startup log
