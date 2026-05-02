# team-red-llm

> Running LLMs locally on AMD GPUs, by people who actually do it.

![demo](./demo.gif)

The CUDA-centric LLM ecosystem treats AMD users as second-class citizens. Half the guides assume `nvidia-smi`, half the tools silently fall back to CPU on ROCm, and the gotchas are scattered across Reddit threads from 2023.

This repo is a community-maintained cookbook + benchmark database for running open-source LLMs on AMD hardware (consumer Radeon, datacenter Instinct, and Strix Halo APUs). If you've built a homelab around Team Red and got burned by some ROCm trap, document it here so the next person doesn't have to.

## What's inside

### 🔧 Setup & Troubleshooting
- **[ROCm-SETUP.md](./ROCm-SETUP.md)** — Install ROCm on your distro without losing your mind
- **[COOKBOOK.md](./COOKBOOK.md)** — Step-by-step guides + every gotcha we've hit
- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** — "GPU not detected", "why is it slow?", and 5 other demons

### 📊 Guides & Reference
- **[VRAM-GUIDE.md](./VRAM-GUIDE.md)** — What models actually fit on your card
- **[PERFORMANCE.md](./PERFORMANCE.md)** — Get the tok/s your GPU actually owes you
- **[benchmarks/results.csv](./benchmarks/results.csv)** — Real tok/s numbers, per GPU + model + quant
- **[hardware/](./hardware/)** — Per-GPU notes (BIOS, drivers, thermals, sweet-spot models)
- **[models/](./models/)** — Per-model notes (working flags, broken quants, architecture quirks)
- **[scripts/](./scripts/)** — Wrappers for `llama-server`, model switching, benchmark runners

## Quick benchmarks

| GPU | Arch | Model | Quant | Mode | Gen tok/s | Prompt tok/s | Source |
|---|---|---|---|---|---|---|---|
| RX 7900 GRE 16GB | gfx1100 | Moonlight-16B-A3B-Instruct | Q6_K | Full GPU | **100.2** | 188.1 | [bench](./benchmarks/results.csv) |
| RX 7900 GRE 16GB | gfx1100 | gemma-4-26B-A4B-it | UD-Q4_K_M | MoE offload (`-ncmoe 6`) | **31.0** | 61.3 | [bench](./benchmarks/results.csv) |
| RX 7900 GRE 16GB | gfx1100 | Qwen3.6-35B-A3B-UD | Q4_K_S | MoE offload (`-ncmoe 32`) | **22.7** | 41.7 | [bench](./benchmarks/results.csv) |
| RX 7900 GRE 16GB | gfx1100 | gemma-4-26B-A4B-it | UD-Q6_K | MoE offload (`-ncmoe 16`) | 17.3 | 80.7 | [bench](./benchmarks/results.csv) |

> **"Mode" column legend:**
> - **Full GPU** — entire model in VRAM, no `-ncmoe`. Capped by GPU memory bandwidth (~576 GB/s on the 7900 GRE) → highest tok/s.
> - **MoE offload** — model too big for VRAM, FFN experts of first N layers in CPU RAM via `-ncmoe N`. Capped by DDR5 bandwidth (~89 GB/s) → much slower but enables 30B+ models on 16GB cards.

PR your numbers to grow this table.

## Supported architectures

| Code | Family | Examples | ROCm support |
|---|---|---|---|
| `gfx1100` | RDNA3 | RX 7900 XTX/XT/GRE | ✅ Mature |
| `gfx1101` | RDNA3 | RX 7800 XT, 7700 XT | ✅ Works |
| `gfx1102` | RDNA3 | RX 7600 | ⚠️ Partial |
| `gfx1200/1201` | RDNA4 | RX 9070 XT, 9060 | ✅ Recent |
| `gfx1150/1151` | Strix Halo | Ryzen AI Max+ 395 | ⚠️ Bleeding edge |
| `gfx942/950` | CDNA3 | MI300X, MI325X | ✅ Datacenter |

## Related tools

### 🔍 [llmfit](https://github.com/AlexsJones/llmfit) — "¿Qué modelos caben en mi GPU?"

A Rust TUI/CLI by [Alex Jones](https://github.com/AlexsJones) that detects your hardware (including AMD GPUs via `rocm-smi`), scores hundreds of models against your VRAM/RAM, and tells you which ones will actually run. Supports MoE architectures, multi-GPU, community benchmarks from [localmaxxing.com](https://localmaxxing.com), and hardware simulation ("what if I had a 7900 XTX?").
   
   ```bash
   # Quick install (all platforms)
   curl -fsSL https://llmfit.axjns.dev/install.sh | sh
   
   # NixOS
   nix run github:AlexsJones/llmfit
   
   # Homebrew
   brew install llmfit
   ```

> **Workflow:** Use `llmfit` to find what fits → come back here for the exact flags and real tok/s numbers.



## How to contribute

1. **Got a benchmark?** Open an issue with the [benchmark template](./.github/ISSUE_TEMPLATE/bench-submission.yml) or PR directly to `benchmarks/results.csv`.
2. **Found a gotcha?** Add it to [COOKBOOK.md](./COOKBOOK.md) under the relevant section.
3. **Tested a new model?** Drop a `models/<model-name>.md` with the flags that worked.
4. **Have a different GPU?** Add `hardware/<gpu>.md` with your specs and any quirks.

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the format.

## Discussions

Use [GitHub Discussions](../../discussions) for questions, hardware shopping advice, "is this worth it" threads, etc. Reserve issues for concrete bugs/contributions.

## License

MIT — go nuts.
