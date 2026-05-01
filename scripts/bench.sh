#!/usr/bin/env bash
# Run llama-bench on a GGUF and emit a CSV row in the format used by
# benchmarks/results.csv.
#
# Usage:
#   ./bench.sh <model-file> [hf-repo] [extra llama-bench args...]
#
# Example:
#   ./bench.sh ~/models/Moonlight-16B-A3B-Instruct-Q6_K.gguf gabriellarson/Moonlight-16B-A3B-Instruct-GGUF
#
# The output line can be appended directly to benchmarks/results.csv.

set -euo pipefail

MODEL="${1:?Usage: $0 <model-file> [hf-repo] [extra args...]}"
HF_REPO="${2:-unknown}"
shift 2 2>/dev/null || shift 1
EXTRA=("$@")

LLAMA_BENCH="${LLAMA_BENCH:-$HOME/llama-cpp-build/build/bin/llama-bench}"
LLAMA_SERVER="${LLAMA_SERVER:-$HOME/llama-cpp-build/build/bin/llama-server}"

if [[ ! -x "$LLAMA_BENCH" ]]; then
  echo "llama-bench not found at $LLAMA_BENCH" >&2
  echo "Set LLAMA_BENCH env var or build it (see COOKBOOK.md)" >&2
  exit 1
fi

if [[ ! -f "$MODEL" ]]; then
  echo "Model file not found: $MODEL" >&2
  exit 1
fi

# Detect GPU info via rocm-smi
GPU_NAME="$(rocm-smi --showproductname 2>/dev/null | grep -oP 'Card series: *\K.+' | head -1 || echo unknown)"
GPU_ARCH="$(rocminfo 2>/dev/null | grep -m1 'Name: *gfx' | grep -oP 'gfx[0-9]+' || echo unknown)"
VRAM_MB="$(rocm-smi --showmeminfo vram 2>/dev/null | grep -oP 'Total Memory.*: *\K[0-9]+' | head -1 || echo 0)"
VRAM_GB=$((VRAM_MB / 1024 / 1024 / 1024))

# Detect llama.cpp build version
BUILD="$($LLAMA_SERVER --version 2>&1 | grep -oP 'version: *\K[0-9]+' | head -1 || echo unknown)"

# Quant string from filename heuristic
QUANT="$(basename "$MODEL" .gguf | grep -oE '(UD-)?(Q[0-9]+_K(_[SLM])?|Q[0-9]+_[01]|F16|BF16|MXFP4|AWQ-?[0-9]+bit|NVFP4)' | tail -1 || echo unknown)"

USER_HANDLE="${GH_USER:-$(git config --get user.name 2>/dev/null || echo unknown)}"
TODAY="$(date -u +%Y-%m-%d)"

echo "Running llama-bench on $MODEL..." >&2
echo "GPU: $GPU_NAME ($GPU_ARCH, ${VRAM_GB}GB VRAM)" >&2
echo "Build: b$BUILD" >&2

# Run benchmark — pp512 (prompt) and tg128 (generation) by default
RESULT="$(env HIP_VISIBLE_DEVICES="${HIP_VISIBLE_DEVICES:-0}" "$LLAMA_BENCH" \
  -m "$MODEL" \
  -p 512 \
  -n 128 \
  -ngl 99 \
  -fa 1 \
  "${EXTRA[@]}" \
  -o csv 2>&1 | tail -3)"

# Parse llama-bench CSV output (last 2 lines: pp and tg)
PP_TPS="$(echo "$RESULT" | grep -E '"pp512"' | grep -oP 'avg_ts.*?\K[0-9.]+' | head -1 || echo "?")"
TG_TPS="$(echo "$RESULT" | grep -E '"tg128"' | grep -oP 'avg_ts.*?\K[0-9.]+' | head -1 || echo "?")"

# Fallback: grep any t/s number
if [[ "$PP_TPS" == "?" ]]; then
  TPS_VALUES=($(echo "$RESULT" | grep -oP '[0-9]+\.[0-9]+(?= ± )' | tail -2))
  PP_TPS="${TPS_VALUES[0]:-?}"
  TG_TPS="${TPS_VALUES[1]:-?}"
fi

# Build a CSV row
FLAGS_STR="-ngl 99 -fa 1 ${EXTRA[*]}"
echo
echo "=== CSV row (append to benchmarks/results.csv) ==="
echo "$GPU_NAME,$GPU_ARCH,$VRAM_GB,$HF_REPO,$QUANT,llama.cpp,b$BUILD,$TG_TPS,$PP_TPS,512,\"$FLAGS_STR\",$USER_HANDLE,$TODAY,llama-bench pp512/tg128
"
