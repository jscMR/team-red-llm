# ROCm Setup Guide

> Getting ROCm running on consumer AMD GPUs without crying.

This guide covers the most common distros. Pick yours and follow the numbered steps.

---

## Before you start

Check your GPU is supported:

```bash
# Run this after installing ROCm to verify
rocminfo | grep "Marketing Name"
```

| GPU | gfx code | ROCm 6.1+ | ROCm 6.3+ |
|-----|----------|-----------|-----------|
| RX 7900 XTX/XT | gfx1100 | ✅ | ✅ |
| RX 7900 GRE | gfx1100 | ✅ | ✅ |
| RX 7800 XT | gfx1101 | ✅ | ✅ |
| RX 7700 XT | gfx1101 | ✅ | ✅ |
| RX 7600 | gfx1102 | ⚠️ Partial | ⚠️ Partial |
| RX 9070 XT | gfx1200 | ❌ | ✅ |
| RX 9060 | gfx1201 | ❌ | ✅ |

---

## Ubuntu 24.04

> **TODO:** Complete step-by-step. Include kernel params, firmware, and post-install verification.

```bash
# 1. Install kernel headers and firmware
sudo apt update
sudo apt install "linux-headers-$(uname -r)" "linux-modules-extra-$(uname -r)"
# TODO: Confirm exact package names for 24.04

# 2. Add ROCm repo
# TODO: repo URL and key

# 3. Install ROCm
# TODO: Package names (rocm-hip-sdk vs rocm-hip-libraries)

# 4. Add user to groups
sudo usermod -a -G render,video $USER

# 5. Reboot
sudo reboot

# 6. Verify
rocminfo | grep "Marketing Name"
rocm-smi
```

**Gotchas on Ubuntu 24.04:**
- TODO: kernel 6.8 vs ROCm compatibility
- TODO: which amdgpu-dkms version

---

## Ubuntu 22.04

> **TODO:** Most stable combination. Document the known-working ROCm 6.1.x flow.

```bash
# TODO: Step by step
```

---

## Fedora 40/41

> **TODO:** Community request is high. Needs testing.

```bash
# TODO: dnf-based install
```

---

## Arch Linux

> **TODO:** AUR packages. Some success stories on r/LocalLLaMA.

```bash
# TODO: yay/pacman flow, which AUR packages actually work
```

---

## NixOS

See [COOKBOOK.md § Running on NixOS](COOKBOOK.md#running-on-nixos) for the full config.

Minimal `configuration.nix` additions:

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

**Gotchas on NixOS:**
- `llama-cpp` in nixpkgs is **CPU-only**. Install `llama-cpp-rocm` instead.
- OpenCL ICD path must be set manually: set `OCL_ICD_VENDORS` to the `rocm-merged` store path.
- Use `programs.nix-ld.enable = true` if you need npm/pip-installed tools (Claude Code, Open WebUI).
- Build llama.cpp from source in a `nix-shell` for latest features. See `scripts/build-llama-cpp.sh`.

---

## WSL2 (Windows)

> **TODO:** Huge demand, very few guides. Document GPU-P pass-through, kernel version requirements, and Windows driver compatibility.

```bash
# TODO: Step by step for WSL2 + ROCm
# Known: needs kernel >= 6.x, specific Windows driver version
# Known: GPU-P must show the GPU in /dev/dri
```

---

## Docker / Podman

> **TODO:** Containerized ROCm. Lower friction, especially for NixOS/Fedora.

```bash
# TODO: rocm/dev-ubuntu-22.04 or similar base image
# TODO: --device=/dev/kfd --device=/dev/dri --security-opt seccomp=unconfined
```

---

## Post-install verification

Regardless of distro, verify with these commands:

```bash
# 1. ROCm sees the GPU
rocminfo | grep -E "Agent|Name:|gfx"
# Expected: Agent 2, Name: gfx1100, Marketing Name: AMD Radeon RX 7900 GRE

# 2. OpenCL works (optional, only needed for OpenCL workloads)
clinfo | grep "Number of platforms"
# Expected: 1 (not 0)

# 3. PyTorch sees the GPU (if using PyTorch)
python3 -c "import torch; print(torch.cuda.is_available())"
# Expected: True

# 4. rocm-smi shows the card
rocm-smi
# Expected: GPU with correct VRAM, temp, and power
```

---

## Common failure modes

- **`rocminfo` shows only CPU agents:** amdgpu kernel module not loaded or wrong version. Check `lsmod | grep amdgpu`.
- **`rocminfo` works but PyTorch doesn't:** PyTorch was installed without ROCm support. Use `pip install torch --index-url https://download.pytorch.org/whl/rocm6.1`.
- **`Permission denied` on `/dev/kfd` or `/dev/dri/render*`:** User is not in the `render` and `video` groups. Log out/in after `usermod`.
- **HIP out of memory during model loading:** Either the model is too big (use `-ncmoe` for MoE, lower quant for dense) or another process is using VRAM.

---

## Contributions wanted

If you've successfully installed ROCm on a distro not listed here, PR your steps. Include:
- Distro + version
- ROCm version
- Kernel version
- Exact package names / commands
- Any gotchas you hit
