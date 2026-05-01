#!/usr/bin/env bash
# Generic wrapper for llama-server on AMD GPUs.
#
# Usage:
#   ./run-model.sh <model-file> [port] [extra-flags...]
#
# Example:
#   ./run-model.sh ~/models/Moonlight-16B-A3B-Instruct-Q6_K.gguf
#   ./run-model.sh ~/models/Qwen3.6-35B-A3B-UD-Q4_K_S.gguf 8002 -ncmoe 32 -c 65536

set -euo pipefail

MODEL="${1:?Usage: $0 <model-file> [port] [extra-flags...]}"
PORT="${2:-8001}"
shift 2 2>/dev/null || shift 1
EXTRA_FLAGS=("$@")

LLAMA_SERVER="${LLAMA_SERVER:-$HOME/llama-cpp-build/build/bin/llama-server}"

if [[ ! -x "$LLAMA_SERVER" ]]; then
  echo "llama-server not found at $LLAMA_SERVER" >&2
  echo "Set LLAMA_SERVER env var or build it (see COOKBOOK.md)" >&2
  exit 1
fi

if [[ ! -f "$MODEL" ]]; then
  echo "Model file not found: $MODEL" >&2
  exit 1
fi

ALIAS=$(basename "$MODEL" .gguf | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

exec env HIP_VISIBLE_DEVICES="${HIP_VISIBLE_DEVICES:-0}" "$LLAMA_SERVER" \
  --model "$MODEL" \
  --port "$PORT" \
  --alias "$ALIAS" \
  -c "${CTX:-32768}" \
  -ngl 99 \
  -fa on \
  -ctk q8_0 -ctv q8_0 \
  --jinja \
  "${EXTRA_FLAGS[@]}"
