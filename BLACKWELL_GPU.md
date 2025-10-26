# Blackwell GPU Setup Guide

## Requirements for Blackwell GPUs (RTX 6000 Pro and similar)

Blackwell GPUs (sm_90 architecture) require **open-source NVIDIA kernel modules** instead of the proprietary ones. This is a hardware requirement and not optional.

### Symptoms of Using Wrong Driver

If you see this error in `dmesg`:
```
NVRM: The NVIDIA GPU 0000:03:00.0 (PCI ID: 10de:2bb1)
NVRM: installed in this system requires use of the NVIDIA open kernel modules.
```

Then you need to install the open kernel modules as described below.

## Installation Steps

### 1. Install NVIDIA Driver with Open Kernel Modules

#### Option A: Using .run Installer (Recommended)

```bash
# Download latest driver (580+ for Blackwell)
wget https://download.nvidia.com/XFree86/Linux-x86_64/580.95.05/NVIDIA-Linux-x86_64-580.95.05.run

# Install with open kernel modules
chmod +x NVIDIA-Linux-x86_64-580.95.05.run
sudo ./NVIDIA-Linux-x86_64-580.95.05.run --kernel-module-type=open --dkms --silent
```

#### Option B: Using Package Manager (Ubuntu)

```bash
# Remove old drivers
sudo apt remove --purge nvidia-*

# Install driver with open modules
sudo apt install nvidia-driver-580-open nvidia-dkms-580-open

# Reboot
sudo reboot
```

### 2. Verify Installation

After installation, verify the open modules are loaded:

```bash
# Check module status
dkms status

# Should show: nvidia/580.95.05, <kernel-version>, x86_64: installed

# Verify GPU is detected
nvidia-smi

# Should show your GPU with driver version 580+
```

### 3. CUDA Setup

Install CUDA 12.8+ for best compatibility:

```bash
# Add CUDA repository (Ubuntu 24.04)
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt update

# Install CUDA toolkit
sudo apt install cuda-toolkit-12-9

# Add to PATH
echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

### 4. Compile llama.cpp for Blackwell

Build with sm_90 architecture support:

```bash
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
mkdir build && cd build

# For Blackwell (sm_90)
cmake .. \
  -DGGML_CUDA=ON \
  -DCMAKE_CUDA_ARCHITECTURES=90 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc \
  -DCMAKE_CUDA_FLAGS="-allow-unsupported-compiler"

cmake --build . --config Release -j $(nproc)
```

Verify the build:
```bash
./bin/llama-server --version
```

## Troubleshooting

### "No devices were found"

1. **Check if modules are loaded**:
   ```bash
   lsmod | grep nvidia
   ```
   
   Should show `nvidia`, `nvidia_uvm`, etc.

2. **Load modules manually** (if not loaded):
   ```bash
   sudo modprobe nvidia
   sudo modprobe nvidia_uvm
   ```

3. **Check kernel logs**:
   ```bash
   sudo dmesg | grep -i nvidia
   ```

### Module Not Loading After Reboot

1. **Verify DKMS status**:
   ```bash
   dkms status
   ```

2. **Rebuild if needed**:
   ```bash
   sudo dkms remove nvidia/580.95.05 --all
   sudo dkms install nvidia/580.95.05
   ```

### Still Using Proprietary Modules

Check which module type is loaded:
```bash
cat /proc/driver/nvidia/version
```

Should NOT mention "proprietary". If it does, the open modules aren't being used.

## Performance Notes

### Blackwell-Specific Considerations

1. **sm_90 Kernel Maturity**: As of 2025-10, Blackwell kernels are still maturing
   - FlashAttention-4 not yet available for sm_90
   - Current performance: 20-25 tok/s for AWQ, 15-20 tok/s for EXL2
   - Expect 50-65 tok/s when FA4 becomes available

2. **Memory**: RTX 6000 Pro has 97GB VRAM
   - Can run 123B models at Q4 quantization
   - IQ4_NL and Q4_K_M recommended for GGUF
   - 4.0-4.5 bpw recommended for EXL2

3. **Quantization Recommendations**:
   - **GGUF**: Q4_K_M or IQ4_NL for 70B-123B models
   - **AWQ**: 4-bit for all model sizes
   - **EXL2**: 4.0-4.5 bpw for 70B-123B models

## Required Software Versions

- **Driver**: 580+ with open kernel modules
- **CUDA**: 12.8+ (12.9 recommended)
- **Linux Kernel**: 6.8+ (for best compatibility)
- **DKMS**: Latest version from package manager

## Architecture Details

- **Compute Capability**: sm_90
- **GPU Code**: GB100 (for data center) / GB202 (for workstation)
- **PCI ID**: 10de:2bb1 and similar
- **Required Module**: nvidia-open (not nvidia-proprietary)

## Verification Checklist

Before using the router with Blackwell GPUs:

- [ ] `nvidia-smi` shows driver 580+
- [ ] `dkms status` shows nvidia open modules installed
- [ ] `lsmod | grep nvidia` shows nvidia modules loaded
- [ ] `cat /proc/driver/nvidia/version` doesn't mention "proprietary"
- [ ] CUDA compiler works: `nvcc --version` shows 12.8+
- [ ] llama.cpp compiled with `-DCMAKE_CUDA_ARCHITECTURES=90`

## Additional Resources

- [NVIDIA Open GPU Kernel Modules](https://github.com/NVIDIA/open-gpu-kernel-modules)
- [Blackwell Architecture Whitepaper](https://www.nvidia.com/en-us/data-center/technologies/blackwell-architecture/)
- [CUDA Toolkit Documentation](https://docs.nvidia.com/cuda/)

## Support

For issues specific to Blackwell GPUs and this router, check:
- `dmesg | grep nvidia` for kernel messages
- `journalctl -u llm-router -n 50` for router logs
- Backend service logs for model loading issues
