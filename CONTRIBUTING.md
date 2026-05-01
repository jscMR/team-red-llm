# Contributing

Thanks for sharing what you've learned. This repo only works if AMD homelabbers actually contribute, so the bar for PRs is intentionally low.

## What we accept

| Type | Where | Acceptance bar |
|---|---|---|
| Benchmark numbers | `benchmarks/results.csv` | One row, no review needed beyond format |
| New model notes | `models/<model>.md` | Must include working `llama-server` config |
| New hardware notes | `hardware/<gpu>.md` | Real benchmarks > theoretical specs |
| Cookbook fixes/additions | `COOKBOOK.md` | Must reference what symptom it solves |
| Scripts | `scripts/` | Bash preferred, must be idempotent |
| Typo fixes | anywhere | Just send it |

## What we don't accept

- Benchmarks without flags / without a build identifier (not reproducible)
- "I think this should work" without testing
- Vendor marketing
- NVIDIA/Apple-only content (use `r/LocalLLaMA`)

## Format conventions

- **Markdown**: ATX headers (`#`), no trailing whitespace, fenced code blocks with language tags
- **CSV**: comma-separated, quote fields containing commas/spaces, ISO 8601 dates (`YYYY-MM-DD`)
- **Shell**: `#!/usr/bin/env bash`, `set -euo pipefail`, one logical step per script
- **No images** unless they're charts of benchmark data — keep it plain text

## Reproducibility checklist for benchmarks

Before submitting a `tok/s` number, verify:

1. The build supports your GPU (`libggml-hip.so` exists)
2. All layers actually offloaded (`offloaded N/N layers to GPU` in logs)
3. No silent CPU fallback (`rocm-smi` shows >50% VRAM, CPU under 100%)
4. Number is from `llama-bench` or `llama-server timings`, not a stopwatch

## License

By contributing, you agree your contribution is licensed under MIT (see [LICENSE](./LICENSE)).
