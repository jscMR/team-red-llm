     1|# VRAM Guide
     2|
     3|> "What model can I actually run on my GPU?"
     4|
     5|If you have an AMD card and you've asked this question, you're not alone. Here are the answers.
     6|
     7|---
     8|
     9|## Quick lookup
    10|
    11|Find your VRAM, pick a row. Tok/s numbers are **real measurements** from [our benchmarks](benchmarks/results.csv) — not estimates.
    12|
    13|### 8 GB VRAM
    14|Examples: RX 7600, RX 6600 XT
    15|
    16|| Model | Quant | Active / Total | Tok/s gen | Mode |
    17||-------|-------|---------------|-----------|------|
    18|| Qwen 2.5 7B | Q5_K_M | — | ~60-80 ⚠️ | Full GPU |
    19|| Phi-4 14B | Q4_K_M | — | ~30-50 ⚠️ | Full GPU |
    20|| Llama 3.1 8B | Q4_K_M | — | ~50-70 ⚠️ | Full GPU |
    21|| Gemma 3 4B | Q6_K | — | ~100+ ⚠️ | Full GPU |
    22|
    23|> ⚠️ = estimated from similar arch, not yet benchmarked. [Submit yours](CONTRIBUTING.md).
    24|
    25|### 12 GB VRAM
    26|Examples: RX 7700 XT, RX 6750 XT
    27|
    28|| Model | Quant | Active / Total | Tok/s gen | Mode |
    29||-------|-------|---------------|-----------|------|
    30|| Mistral Small 22B | Q4_K_M | — | ~30-50 ⚠️ | Full GPU |
    31|| Qwen 2.5 14B | Q5_K_M | — | ~40-60 ⚠️ | Full GPU |
    32|| Llama 3.1 8B | Q8_0 | — | ~50-80 ⚠️ | Full GPU |
    33|| Command R 35B | Q3_K_M | — | ~15-25 ⚠️ | MoE offload |
    34|
    35|### 16 GB VRAM
    36|Examples: RX 7800 XT, RX 7900 GRE, RX 6800 XT
    37|
    38|| Model | Quant | Active / Total | Tok/s gen | Mode |
    39||-------|-------|---------------|-----------|------|
    40|| **Moonlight 16B A3B** | Q6_K | 3B/16B | **100.2** ✅ | Full GPU |
    41|| **Gemma 4 26B A4B** | UD-Q4_K_M | 4B/26B | **31.0** ✅ | MoE offload (`-ncmoe 6`) |
    42|| **Qwen 3.6 35B A3B** | Q4_K_S | 3B/35B | **22.7** ✅ | MoE offload (`-ncmoe 32`) |
    43|| Gemma 4 26B | UD-Q6_K | 4B/26B | 17.3 ✅ | MoE offload (`-ncmoe 16`) |
    44|| Qwen 2.5 14B | Q6_K | — | ~60-90 ⚠️ | Full GPU |
    45|
    46|> ✅ = real benchmarks on RX 7900 GRE.
    47|
    48|### 20 GB VRAM
    49|Examples: RX 7900 XT
    50|
    51|| Model | Quant | Active / Total | Tok/s gen | Mode |
    52||-------|-------|---------------|-----------|------|
    53|| Qwen 2.5 32B | Q4_K_M | — | ~25-45 ⚠️ | Full GPU |
    54|| Mixtral 8x7B | Q5_K_M | 13B/47B | ~30-50 ⚠️ | Full GPU |
    55|| DeepSeek V2 Lite | Q6_K | 2.4B/16B | ~100+ ⚠️ | Full GPU |
    56|
    57|### 24 GB VRAM
    58|Examples: RX 7900 XTX
    59|
    60|| Model | Quant | Active / Total | Tok/s gen | Mode |
    61||-------|-------|---------------|-----------|------|
    62|| Qwen 2.5 32B | Q5_K_M | — | ~30-60 ⚠️ | Full GPU |
    63|| Mistral Small 3 22B | Q6_K | — | ~40-70 ⚠️ | Full GPU |
    64|| Llama 3.1 70B | Q3_K_M | — | ~10-20 ⚠️ | Full GPU |
    65|| Command R+ 104B | Q4_K_M | — | ~5-10 ⚠️ | MoE offload |
    66|
    67|> ⚠️ = estimated or from community reports. PR your real numbers.
    68|
    69|---
    70|
    71|## What if my card isn't listed?
    72|
    73|Rough heuristic: same VRAM ≈ same model capacity. A 7800 XT (16GB) and a 7900 GRE (16GB) can run the same models — the GRE is ~15-20% faster due to higher memory bandwidth.
    74|
    75|Use [llmfit](https://github.com/AlexsJones/llmfit) to get model recommendations tailored to your exact hardware.
    76|
    77|---
    78|
    79|## Key concepts
    80|
    81|### Full GPU vs MoE offload
    82|
    83|- **Full GPU** — Model weights + KV cache fit entirely in VRAM. Fast, limited by memory bandwidth (~576 GB/s on 7900 GRE). Use `-ngl 99`.
    84|- **MoE offload** — Model too big for VRAM. FFN expert weights of first N layers stay in CPU RAM via `-ncmoe N`. Much slower (limited by DDR5 ~80 GB/s) but enables 30B+ models on 16GB cards. See [COOKBOOK.md § MoE offloading](COOKBOOK.md#moe-offloading-with--ncmoe).
    85|
    86|### Quantization impact
    87|
    88|Lower quant = less VRAM but lower quality:
    89|
    90|| Quant | VRAM multiplier | Quality |
    91||-------|----------------|---------|
    92|| Q8_0 | 1.0× params in GB | Reference |
    93|| Q6_K | 0.75× | Near lossless |
    94|| Q5_K_M | 0.67× | Excellent |
    95|| Q4_K_M | 0.50× | Very good |
    96|| Q4_K_S | 0.47× | Good |
    97|| Q3_K_M | 0.38× | Usable |
    98|
    99|For 16B params at Q4_K_M: ~8 GB VRAM. At Q6_K: ~12 GB VRAM.
   100|
   101|---
   102|
   103|## Pro tip: check before downloading
   104|
   105|Use `llmfit` to check if a model fits your GPU before spending 20 minutes downloading it.
   106|
   107|```bash
   108|# Install
   109|curl -fsSL https://llmfit.axjns.dev/install.sh | sh
   110|
   111|# Run (auto-detects your GPU)
   112|llmfit
   113|```
   114|
   115|Then cross-reference with our [benchmarks](benchmarks/results.csv) for real tok/s numbers with the exact flags.
   116|
