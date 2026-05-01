# Cookbook

Battle-tested recipes for running LLMs on AMD GPUs. Each section ends with the gotcha we hit so you don't have to.

## Table of contents

- [Building llama.cpp with HIP](#building-llamacpp-with-hip)
- [Multi-GPU and the iGPU trap](#multi-gpu-and-the-igpu-trap)
- [Unsupported quantizations on ROCm](#unsupported-quantizations-on-rocm)
- [MoE offloading with `-ncmoe`](#moe-offloading-with--ncmoe)
- [llama-server flags reference](#llama-server-flags-reference)
- [Running on NixOS](#running-on-nixos)
- [Diagnosing CPU-only fallback](#diagnosing-cpu-only-fallback)

---

## Building llama.cpp with HIP

The cmake flag `GGML_HIPBLAS=ON` is **deprecated** but still accepted silently. cmake won't error, the build will succeed, and you'll end up with a CPU-only binary that ignores `-ngl`.

**Wrong (silent CPU build):**

```bash
cmake -B build -DGGML_HIPBLAS=ON -DAMDGPU_TARGETS=gfx1100 -DCMAKE_BUILD_TYPE=Release
```

**Correct:**

```bash
HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -R)" \
cmake -S . -B build \
  -DGGML_HIP=ON \
  -DAMDGPU_TARGETS=gfx1100 \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_CURL=OFF
cmake --build build --config Release -j$(nproc)
```

Pick `AMDGPU_TARGETS` from your GPU's gfx code (see README table). Multiple targets are valid: `-DAMDGPU_TARGETS="gfx1100;gfx1101"`.

**How to verify the build actually has GPU support:**

```bash
ls build/bin/*.so | grep hip
# Must list libggml-hip.so. If only libggml-cpu.so appears, the build is broken.

./build/bin/llama-server --version
# Must print "ggml_cuda_init: found N ROCm devices". If it prints
# "no usable GPU found", you have the deprecated-flag bug above.
```

---

## Multi-GPU and the iGPU trap

If you have a Ryzen with an integrated GPU (like the 7600X's `gfx1036`), llama.cpp will detect **both** GPUs and try to split the model across them. The iGPU is far slower and, more importantly, **its kernels weren't compiled** if you used `-DAMDGPU_TARGETS=gfx1100`.

Symptom:

```
ROCm error: invalid device function
  current device: 1, in function ggml_cuda_compute_forward
```

Fix: limit ROCm to the dedicated GPU only.

```bash
HIP_VISIBLE_DEVICES=0 llama-server --model ... -ngl 99
```

Verify it sees only one device:

```
ggml_cuda_init: found 1 ROCm devices (Total VRAM: 16368 MiB):
  Device 0: AMD Radeon RX 7900 GRE, gfx1100
```

If you really want multi-GPU (two dedicated cards), build with both targets in `AMDGPU_TARGETS` and use `--tensor-split` to control allocation.

---

## Unsupported quantizations on ROCm

Some quantization formats only work on CUDA right now. If your model contains them and you're on ROCm, llama.cpp falls back to CPU **silently** for those tensors.

| Format | ROCm support | Notes |
|---|---|---|
| Q4_K_M, Q5_K_M, Q6_K, Q8_0 | ✅ | Standard, always works |
| AWQ-4bit | ❌ in llama.cpp | vLLM-only |
| MXFP4 | ❌ as of llama.cpp b8999 | Native format for OpenAI gpt-oss-20b — falls back to CPU |
| NVFP4 | ❌ | NVIDIA-specific |
| GPTQ-Int4 | ❌ in llama.cpp | vLLM-only |

How to check: after loading, look for `mxfp4` or other suspect types in the tensor list:

```
llama_model_loader: - type mxfp4: 72 tensors
load_tensors: CPU_Mapped model buffer size = 11073.83 MiB  ← BAD
load_tensors: ROCm0 model buffer size = 13348.81 MiB  ← GOOD
```

If you see `CPU_Mapped` for the model buffer (not just for embeddings), the model is fully on CPU.

**Workaround:** find a different GGUF repo that uses standard quants. Search HuggingFace excluding "MXFP4" / "NVFP4" / "AWQ" in the filename.

---

## MoE offloading with `-ncmoe`

For MoE models too big to fit in VRAM, `-ncmoe N` keeps the FFN expert weights of the first N layers in CPU RAM while keeping attention + shared weights on GPU. This is what lets you run 35B+ MoE models on 16GB cards.

```bash
HIP_VISIBLE_DEVICES=0 llama-server \
  --model Qwen3.6-35B-A3B.gguf \
  -ngl 99 \
  -ncmoe 32 \
  -fa on \
  -ctk q8_0 -ctv q8_0
```

Tuning:

- Start with `-ncmoe 32` on a 16GB card
- If OOM: increase by 8 (more experts on CPU)
- If you have headroom (>2GB free VRAM): decrease by 4 (more experts on GPU = faster)

The bottleneck is DDR5 bandwidth streaming experts to GPU per token, not GPU compute.

---

## llama-server flags reference

The flags we always set for AMD inference:

```bash
-ngl 99               # Offload all layers to GPU
-fa on                # Flash attention (required for KV cache quantization)
-ctk q8_0 -ctv q8_0   # Quantize KV cache → ~10 KB/token vs ~40 KB unquantized
-c 32768              # Context length (adjust to taste)
--jinja               # Use the model's jinja chat template (needed for newer models)
--no-context-shift    # Recommended for thinking models (don't rotate context)
```

For agent / tool-calling workloads, also:

```bash
--cache-ram 0         # Disable prompt cache (avoids idle CPU usage)
-t 6                  # Limit CPU threads if you don't want it eating all cores
```

---

## Running on NixOS

The `llama-cpp-rocm` package in `nixpkgs` works for older models but lags 1500+ builds behind master. New architectures (e.g. `qwen35moe`) won't load. Solutions:

1. **Build from source in a `nix-shell`** (see [Building llama.cpp with HIP](#building-llamacpp-with-hip))
2. **Enable `programs.nix-ld.enable = true;`** so binaries from `npm`/`pip`/curl-based installers work (e.g. Claude Code, Open WebUI)
3. Add `rocmPackages.{clr,hipblas,rocblas,rocm-smi}` to `environment.systemPackages` for runtime libs

Example minimal NixOS config addition:

```nix
{
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      rocmPackages.clr
      rocmPackages.rocblas
      rocmPackages.hipblas
    ];
  };
  systemd.tmpfiles.rules = [
    "L+ /opt/rocm - - - - ${pkgs.rocmPackages.clr}"
  ];
  environment.systemPackages = with pkgs; [
    rocmPackages.rocm-smi
    rocmPackages.rocminfo
  ];
  users.users.<you>.extraGroups = [ "video" "render" ];
}
```

---

## Diagnosing CPU-only fallback

Common symptoms: low tok/s (under 15 for ~20B models), CPU at 400-500%, GPU at 0-7% on `rocm-smi`.

Checklist:

1. **Is the binary GPU-capable?** `ls build/bin/*.so | grep hip` — must show `libggml-hip.so`
2. **Does it detect the GPU at startup?** Look for `ggml_cuda_init: found N ROCm devices` in logs. If you see `warning: no usable GPU found` instead, the build is wrong.
3. **Did it offload layers?** Look for `load_tensors: offloaded N/N layers to GPU` and `ROCm0 model buffer size = X MiB`. If it says `CPU_Mapped model buffer size = X MiB` for the model itself, no offload happened.
4. **Is the quant supported?** Check the tensor type list — see [Unsupported quantizations](#unsupported-quantizations-on-rocm).
5. **Multi-GPU crash?** Set `HIP_VISIBLE_DEVICES=0`.
6. **Is rocm-smi happy?** Run `rocm-smi` — confirm your card shows up and reports VRAM correctly.

If all checks pass and you're still slow, run `llama-bench` for a clean benchmark unaffected by chat overhead:

```bash
llama-bench -m model.gguf -p 512 -n 128 -ngl 99
```
