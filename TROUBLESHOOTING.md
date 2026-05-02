     1|# Troubleshooting
     2|
     3|> "It worked yesterday!" — every AMD user ever.
     4|
     5|Quick fixes for the 7 demons of ROCm inference. Start from the top and work down.
     6|
     7|---
     8|
     9|## Symptom / error → fix
    10|
    11|| Symptom | Probable cause | Fix |
    12||---------|---------------|-----|
    13|| `rocminfo` shows GPU but `clinfo` says 0 platforms | OpenCL ICD path not set | [OpenCL not detecting GPU](#opencl-not-detecting-gpu) |
    14|| ROCm error: `invalid device function` | iGPU clash | [iGPU clash](#igpu-clash) |
    15|| `no usable GPU found` on startup | Wrong build (GGML_HIPBLAS vs GGML_HIP) | [CPU-only build](#cpu-only-build) |
    16|| All layers on CPU despite `-ngl 99` | Quant not supported on ROCm | [Unsupported quantization](#unsupported-quantization) |
    17|| OOM even though VRAM should fit | MoE total params > VRAM | [MoE offloading](#moe-offloading) |
    18|| Slow (<15 tok/s on >7B model) | Silent CPU fallback | [CPU-only fallback diagnosis](#cpu-only-fallback-diagnosis) |
    19|| `rocminfo` doesn't see the GPU at all | Kernel driver / permissions | [GPU not detected at all](#gpu-not-detected-at-all) |
    20|
    21|---
    22|
    23|## OpenCL not detecting GPU
    24|
    25|**Symptom:** `rocminfo` shows your GPU but `clinfo` reports `Number of platforms: 0`.
    26|
    27|**Fix:** The OpenCL ICD loader doesn't know where ROCm lives.
    28|
    29|```bash
    30|# Find the amdocl64.icd file
    31|find /opt/rocm* /nix/store -name "amdocl64.icd" 2>/dev/null
    32|
    33|# Set the environment variable (add to your shell profile)
    34|export OCL_ICD_VENDORS=/opt/rocm/etc/OpenCL/vendors
    35|
    36|# On NixOS:
    37|export OCL_ICD_VENDORS=$(find /nix/store -path "*/rocm-merged/etc/OpenCL/vendors" 2>/dev/null | head -1)
    38|```
    39|
    40|---
    41|
    42|## iGPU clash
    43|
    44|**Symptom:**
    45|```
    46|ROCm error: invalid device function
    47|  current device: 1, in function ggml_cuda_compute_forward
    48|```
    49|
    50|**Cause:** Ryzen 7000/8000 CPUs have integrated graphics (`gfx1036`). llama.cpp sees both GPUs and tries to split the model, but the iGPU kernels weren't compiled.
    51|
    52|**Fix:** Limit to dedicated GPU only.
    53|
    54|```bash
    55|HIP_VISIBLE_DEVICES=0 llama-server --model ... -ngl 99
    56|```
    57|
    58|Verify:
    59|```
    60|ggml_cuda_init: found 1 ROCm devices (Total VRAM: 16368 MiB):
    61|  Device 0: AMD Radeon RX 7900 GRE, gfx1100
    62|```
    63|
    64|---
    65|
    66|## CPU-only build
    67|
    68|**Symptom:** llama.cpp starts with `warning: no usable GPU found` or `ggml_cuda_init: no usable GPU`. `rocm-smi` shows the GPU correctly.
    69|
    70|**Cause:** You used the deprecated cmake flag `-DGGML_HIPBLAS=ON`. cmake doesn't error — it builds a CPU-only binary.
    71|
    72|**Fix:** Rebuild with `-DGGML_HIP=ON`. See [COOKBOOK.md § Building llama.cpp with HIP](COOKBOOK.md#building-llamacpp-with-hip).
    73|
    74|Verify:
    75|```bash
    76|ls build/bin/*hip*           # Must show libggml-hip.so
    77|./build/bin/llama-server --version 2>&1 | grep "ROCm devices"
    78|```
    79|
    80|---
    81|
    82|## Unsupported quantization
    83|
    84|**Symptom:** Model loads but inference is extremely slow. `rocm-smi` shows GPU at <10%.
    85|
    86|**Cause:** Some quantization formats only work on CUDA. llama.cpp falls back to CPU silently.
    87|
    88|| Format | ROCm support |
    89||--------|-------------|
    90|| Q4_K_M, Q5_K_M, Q6_K, Q8_0 | ✅ Works |
    91|| AWQ-4bit | ❌ CPU fallback |
    92|| MXFP4 | ❌ CPU fallback |
    93|| NVFP4 | ❌ CPU fallback |
    94|| GPTQ-Int4 | ❌ CPU fallback |
    95|
    96|**Fix:** Use a different GGUF repo with standard quants. Check tensor types after loading:
    97|```
    98|load_tensors: ROCm0 model buffer size = 13348 MiB  ← GOOD
    99|load_tensors: CPU_Mapped model buffer size = 11073 MiB  ← BAD (all on CPU)
   100|```
   101|
   102|---
   103|
   104|## MoE offloading
   105|
   106|**Symptom:** OOM with `-ngl 99` on MoE models (Mixtral, DeepSeek-V2, Qwen3 MoE, Gemma 4).
   107|
   108|**Cause:** MoE models have huge total parameters (e.g., Mixtral 8x7B = 47B total). They fit in RAM but not VRAM.
   109|
   110|**Fix:** Use `-ncmoe N` to keep FFN expert weights of the first N layers in CPU RAM:
   111|
   112|```bash
   113|llama-server --model model.gguf -ngl 99 -ncmoe 32
   114|```
   115|
   116|See [COOKBOOK.md § MoE offloading](COOKBOOK.md#moe-offloading-with--ncmoe).
   117|
   118|---
   119|
   120|## CPU-only fallback diagnosis
   121|
   122|**Symptom:** Low tok/s (<15 for 7B+ models), CPU at 400-500%, GPU at 0-7% on `rocm-smi`.
   123|
   124|**Full checklist:**
   125|
   126|1. **Is the binary GPU-capable?** `ls build/bin/*.so | grep hip`
   127|2. **Does it detect the GPU?** Look for `ggml_cuda_init: found N ROCm devices`
   128|3. **Did it offload layers?** Look for `offloaded N/N layers to GPU`
   129|4. **Is the quant supported?** Check tensor type list for `mxfp4`, `awq`, etc.
   130|5. **Multi-GPU crash?** Set `HIP_VISIBLE_DEVICES=0`
   131|6. **Is rocm-smi happy?** Run `rocm-smi` — confirm VRAM reported correctly
   132|
   133|If all passes and you're still slow, run a clean benchmark:
   134|```bash
   135|llama-bench -m model.gguf -p 512 -n 128 -ngl 99
   136|```
   137|
   138|---
   139|
   140|## GPU not detected at all
   141|
   142|**Symptom:** `rocminfo` returns no agents or only CPU agents.
   143|
   144|**Troubleshooting steps:**
   145|
   146|```bash
   147|# 1. Is the amdgpu kernel module loaded?
   148|lsmod | grep amdgpu
   149|
   150|# 2. Does the render node exist?
   151|ls /dev/dri/render* /dev/kfd
   152|
   153|# 3. Are you in the right groups?
   154|groups | grep -E "video|render"
   155|
   156|# 4. Check kernel command line (GRUB)
   157|cat /proc/cmdline | grep amdgpu
   158|
   159|# 5. Try adding to kernel params (varies by distro):
   160|# amdgpu.ppfeaturemask=0xffffffff amdgpu.dc=1
   161|```
   162|
   163|**If all else fails:** See [ROCm-SETUP.md](ROCm-SETUP.md) for clean installation per distro.
   164|
   165|---
   166|
   167|## Quick wins
   168|
   169|Before deep-diving into any specific fix, run this:
   170|
   171|```bash
   172|# Verify hardware visible to ROCm
   173|rocminfo | grep -E "Agent|Name:|gfx"
   174|
   175|# Verify GPU utilization during inference
   176|watch -n 1 rocm-smi --showuse --showmemuse
   177|
   178|# Verify the binary actually offloads to GPU
   179|llama-server --version 2>&1 | grep "ROCm devices"
   180|
   181|# Clean benchmark
   182|llama-bench -m your-model.gguf -p 512 -n 128 -ngl 99
   183|```
   184|
   185|---
   186|
   187|## Still stuck?
   188|
   189|Open an issue with the [rocm-gotcha template](.github/ISSUE_TEMPLATE/rocm-gotcha.yml). Include:
   190|- GPU model + gfx code
   191|- Distro + ROCm version
   192|- llama.cpp build command + version
   193|- Full startup log
   194|