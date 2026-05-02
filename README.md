     1|     1|# team-red-llm
     2|     2|
     3|     3|> Running LLMs locally on AMD GPUs, by people who actually do it.
     4|     4|
     5|     5|![demo](./demo.gif)
     6|     6|
     7|     7|The CUDA-centric LLM ecosystem treats AMD users as second-class citizens. Half the guides assume `nvidia-smi`, half the tools silently fall back to CPU on ROCm, and the gotchas are scattered across Reddit threads from 2023.
     8|     8|
     9|     9|This repo is a community-maintained cookbook + benchmark database for running open-source LLMs on AMD hardware (consumer Radeon, datacenter Instinct, and Strix Halo APUs). If you've built a homelab around Team Red and got burned by some ROCm trap, document it here so the next person doesn't have to.
    10|    10|
    11|    11|## What's inside
    12|    12|
    13|    13|
    14|    14|### 🔧 Setup & Troubleshooting
    15|    15|- **[ROCm-SETUP.md](./ROCm-SETUP.md)** — Install ROCm on your distro without losing your mind
    16|    16|- **[COOKBOOK.md](./COOKBOOK.md)** — Step-by-step guides + every gotcha we've hit
    17|    17|- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** — "GPU not detected", "why is it slow?", and 5 other demons
    18|    18|
    19|    19|
    20|    20|### 📊 Guides & Reference
    21|    21|- **[VRAM-GUIDE.md](./VRAM-GUIDE.md)** — What models actually fit on your card
    22|    22|- **[PERFORMANCE.md](./PERFORMANCE.md)** — Get the tok/s your GPU actually owes you
    23|    23|- **[benchmarks/results.csv](./benchmarks/results.csv)** — Real tok/s numbers, per GPU + model + quant
    24|    24|- **[hardware/](./hardware/)** — Per-GPU notes (BIOS, drivers, thermals, sweet-spot models)
    25|    25|- **[models/](./models/)** — Per-model notes (working flags, broken quants, architecture quirks)
    26|    26|- **[scripts/](./scripts/)** — Wrappers for `llama-server`, model switching, benchmark runners
    27|    27|
    28|    28|## Quick benchmarks
    29|    29|
    30|    30|| GPU | Arch | Model | Quant | Mode | Gen tok/s | Prompt tok/s | Source |
    31|    31||---|---|---|---|---|---|---|---|
    32|    32|| RX 7900 GRE 16GB | gfx1100 | Moonlight-16B-A3B-Instruct | Q6_K | Full GPU | **100.2** | 188.1 | [bench](./benchmarks/results.csv) |
    33|    33|| RX 7900 GRE 16GB | gfx1100 | gemma-4-26B-A4B-it | UD-Q4_K_M | MoE offload (`-ncmoe 6`) | **31.0** | 61.3 | [bench](./benchmarks/results.csv) |
    34|    34|| RX 7900 GRE 16GB | gfx1100 | Qwen3.6-35B-A3B-UD | Q4_K_S | MoE offload (`-ncmoe 32`) | **22.7** | 41.7 | [bench](./benchmarks/results.csv) |
    35|    35|| RX 7900 GRE 16GB | gfx1100 | gemma-4-26B-A4B-it | UD-Q6_K | MoE offload (`-ncmoe 16`) | 17.3 | 80.7 | [bench](./benchmarks/results.csv) |
    36|    36|
    37|    37|> **"Mode" column legend:**
    38|    38|> - **Full GPU** — entire model in VRAM, no `-ncmoe`. Capped by GPU memory bandwidth (~576 GB/s on the 7900 GRE) → highest tok/s.
    39|    39|> - **MoE offload** — model too big for VRAM, FFN experts of first N layers in CPU RAM via `-ncmoe N`. Capped by DDR5 bandwidth (~89 GB/s) → much slower but enables 30B+ models on 16GB cards.
    40|    40|
    41|    41|PR your numbers to grow this table.
    42|    42|
    43|    43|## Supported architectures
    44|    44|
    45|    45|| Code | Family | Examples | ROCm support |
    46|    46||---|---|---|---|
    47|    47|| `gfx1100` | RDNA3 | RX 7900 XTX/XT/GRE | ✅ Mature |
    48|    48|| `gfx1101` | RDNA3 | RX 7800 XT, 7700 XT | ✅ Works |
    49|    49|| `gfx1102` | RDNA3 | RX 7600 | ⚠️ Partial |
    50|    50|| `gfx1200/1201` | RDNA4 | RX 9070 XT, 9060 | ✅ Recent |
    51|    51|| `gfx1150/1151` | Strix Halo | Ryzen AI Max+ 395 | ⚠️ Bleeding edge |
    52|    52|| `gfx942/950` | CDNA3 | MI300X, MI325X | ✅ Datacenter |
    53|    53|
    54|    54|## Related tools
    55|    55|
    56|    56|### 🔍 [llmfit](https://github.com/AlexsJones/llmfit) — "¿Qué modelos caben en mi GPU?"
    57|    57|
    58|    58|A Rust TUI/CLI by [Alex Jones](https://github.com/AlexsJones) that detects your hardware (including AMD GPUs via `rocm-smi`), scores hundreds of models against your VRAM/RAM, and tells you which ones will actually run. Supports MoE architectures, multi-GPU, community benchmarks from [localmaxxing.com](https://localmaxxing.com), and hardware simulation ("what if I had a 7900 XTX?").
    59|    59|
    60|    60|   ```bash
    61|    61|   # Quick install (all platforms)
    62|    62|   curl -fsSL https://llmfit.axjns.dev/install.sh | sh
    63|    63|
    64|    64|   # NixOS
    65|    65|   nix run github:AlexsJones/llmfit
    66|    66|
    67|    67|   # Homebrew
    68|    68|   brew install llmfit
    69|    69|   ```
    70|    70|
    71|    71|> **Workflow:** Use `llmfit` to find what fits → come back here for the exact flags and real tok/s numbers.
    72|    72|
    73|    73|
    74|    74|
### 🚫 Why we don't recommend Ollama or LM Studio for AMD

Many newcomers reach for Ollama or LM Studio because they "just work" on NVIDIA. On AMD, they don't.

| | Ollama | LM Studio | Manual llama.cpp (this repo) |
|---|---|---|---|
| Detects RX 7900 GRE / 7800 XT | ⚠️ Often fails | ❌ Not supported | ✅ |
| Flash Attention | ❌ Disabled on AMD | ❌ | ✅ `-fa on` |
| Vulkan fallback | ❌ | ❌ | ✅ |
| KV cache quantization | ❌ | ❌ | ✅ `-ctk q8_0 -ctv q8_0` |
| MoE offloading (`-ncmoe`) | ❌ | ❌ | ✅ |
| Performance (8B Q4) | ~35 tok/s | CPU only | **60-100 tok/s** |
| Memory management | ⚠️ OOMs on 16GB | ❌ | ✅ mmap + fine-grained |

**LM Studio** has no AMD GPU support — period. It falls back to CPU silently.

**Ollama** bundles its own ROCm, which conflicts with system ROCm, and only reliably detects the RX 7900 XT/XTX. Even when it works, it's 30-40% slower than a manual build because it lacks Flash Attention and KV cache quantization on AMD.

**Bottom line:** Building llama.cpp from source (or using our `run-model.sh`) is the only path that extracts everything your AMD GPU is capable of.

    75|    75|## How to contribute
    76|    76|
    77|    77|1. **Got a benchmark?** Open an issue with the [benchmark template](./.github/ISSUE_TEMPLATE/bench-submission.yml) or PR directly to `benchmarks/results.csv`.
    78|    78|2. **Found a gotcha?** Add it to [COOKBOOK.md](./COOKBOOK.md) under the relevant section.
    79|    79|3. **Tested a new model?** Drop a `models/<model-name>.md` with the flags that worked.
    80|    80|4. **Have a different GPU?** Add `hardware/<gpu>.md` with your specs and any quirks.
    81|    81|
    82|    82|See [CONTRIBUTING.md](./CONTRIBUTING.md) for the format.
    83|    83|
    84|    84|## Discussions
    85|    85|
    86|    86|Use [GitHub Discussions](../../discussions) for questions, hardware shopping advice, "is this worth it" threads, etc. Reserve issues for concrete bugs/contributions.
    87|    87|
    88|    88|## License
    89|    89|
    90|    90|MIT — go nuts.
    91|    91|
