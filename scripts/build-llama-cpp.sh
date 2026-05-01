#!/usr/bin/env bash
# Build llama.cpp from source with proper HIP/ROCm support.
# Tested on NixOS — adapt the dependency installation for your distro.
#
# Usage:
#   ./build-llama-cpp.sh [target-arch] [build-dir]
#
# Examples:
#   ./build-llama-cpp.sh gfx1100              # RDNA3 (RX 7900 series)
#   ./build-llama-cpp.sh gfx1200              # RDNA4 (RX 9070 series)
#   ./build-llama-cpp.sh "gfx1100;gfx1101"    # Multiple targets

set -euo pipefail

TARGET="${1:-gfx1100}"
BUILD_DIR="${2:-$HOME/llama-cpp-build}"

if [[ ! -d "$BUILD_DIR" ]]; then
  git clone https://github.com/ggerganov/llama.cpp "$BUILD_DIR"
fi

cd "$BUILD_DIR"

# Use nix-shell on NixOS, otherwise assume tools are in PATH
if command -v nix-shell &>/dev/null; then
  nix-shell -p cmake ninja git rocmPackages.clr rocmPackages.hipblas rocmPackages.rocblas --run "
    rm -rf build && \
    HIPCXX=\"\$(hipconfig -l)/clang\" HIP_PATH=\"\$(hipconfig -R)\" \
    cmake -S . -B build \
      -DGGML_HIP=ON \
      -DAMDGPU_TARGETS=\"$TARGET\" \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLAMA_CURL=OFF && \
    cmake --build build --config Release -j\$(nproc)
  "
else
  rm -rf build
  HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -R)" \
    cmake -S . -B build \
      -DGGML_HIP=ON \
      -DAMDGPU_TARGETS="$TARGET" \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLAMA_CURL=OFF
  cmake --build build --config Release -j"$(nproc)"
fi

echo
echo "=== Build complete ==="
echo "Binary: $BUILD_DIR/build/bin/llama-server"
echo
echo "=== GPU detection check ==="
"$BUILD_DIR/build/bin/llama-server" --version 2>&1 | head -5
echo
if ls "$BUILD_DIR/build/bin/"*hip* &>/dev/null; then
  echo "✅ libggml-hip.so present — GPU support compiled in"
else
  echo "❌ No libggml-hip.so found — GPU support is MISSING"
  echo "   Check that hipconfig is in PATH and ROCm is installed"
  exit 1
fi
