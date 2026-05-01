# Submitting a benchmark

Two ways:

## Option 1: PR to `results.csv` (preferred)

Add a row in this format:

```
gpu,gpu_arch,vram_gb,model,quant,backend,build,gen_tps,prompt_tps,context,flags,user,date,notes
```

Field guide:

| Field | Example | Notes |
|---|---|---|
| `gpu` | `RX 7900 GRE` | Marketing name |
| `gpu_arch` | `gfx1100` | Run `rocminfo \| grep gfx` |
| `vram_gb` | `16` | Integer GB |
| `model` | `unsloth/Qwen3-32B-GGUF` | HF repo or canonical name |
| `quant` | `Q6_K` | Exact quant string |
| `backend` | `llama.cpp` | or `vllm`, `mlc`, `koboldcpp` |
| `build` | `b8999` | Build/commit identifier |
| `gen_tps` | `100.2` | Generation tok/s (`predicted_per_second` from llama-server timings) |
| `prompt_tps` | `188.1` | Prompt eval tok/s (`prompt_per_second`) |
| `context` | `32768` | `-c` value at benchmark time |
| `flags` | `"-ngl 99 -fa on -ctk q8_0"` | Quote if it has spaces/commas |
| `user` | `your-gh-handle` | For attribution |
| `date` | `2026-05-02` | ISO 8601 |
| `notes` | `MoE offload via -ncmoe 32` | Anything weird |

## Option 2: Open an issue

Use the [bench-submission](../.github/ISSUE_TEMPLATE/bench-submission.yml) template if you don't want to PR. A maintainer will fold it into the CSV.

## How to get clean numbers

For reproducible results, use `llama-bench` instead of pulling timings from a chat:

```bash
HIP_VISIBLE_DEVICES=0 ./llama-bench \
  -m ~/models/your-model.gguf \
  -p 512 \
  -n 128 \
  -ngl 99 \
  -fa 1
```

Report the `pp512` (prompt) and `tg128` (generation) numbers. Each is averaged over 5 runs.

If you're benchmarking a chat session for "real-world" feel, pull from llama-server's `timings` field on `/v1/chat/completions` responses:

```json
{
  "timings": {
    "prompt_per_second": 188.1,
    "predicted_per_second": 100.2
  }
}
```
