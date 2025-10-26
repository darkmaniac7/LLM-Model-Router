# SGLang Installation Guide for NVIDIA Blackwell GPUs

Complete end-to-end guide for installing SGLang on Ubuntu 24.04 with NVIDIA Blackwell architecture GPUs.

## Prerequisites

### System Requirements
- **OS**: Ubuntu 24.04 LTS
- **GPU**: NVIDIA Blackwell architecture (compute capability 12.0)
- **RAM**: 128GB+ recommended (needed for CUDA kernel compilation with large models)
- **Storage**: 50GB+ for dependencies and model cache

### Required Software Versions
- **NVIDIA Driver**: 580.x+ (Open Kernel Module for Blackwell)
- **CUDA Toolkit**: 12.6 or 13.0
- **Python**: 3.10-3.12
- **GCC**: 11 or 12

## Step 1: Install NVIDIA Drivers (Open Kernel Module)

```bash
# Remove any existing NVIDIA drivers
sudo apt purge -y '*nvidia*' '*cuda*'
sudo apt autoremove -y

# Add NVIDIA repository
sudo add-apt-repository ppa:graphics-drivers/ppa -y
sudo apt update

# Install driver 580+ with open kernel module
sudo apt install -y nvidia-driver-580-open nvidia-utils-580

# Reboot
sudo reboot
```

Verify:
```bash
nvidia-smi  # Should show driver 580.x+
```

## Step 2: Install CUDA Toolkit 12.6

```bash
# Download CUDA 12.6 installer
wget https://developer.download.nvidia.com/compute/cuda/12.6.0/local_installers/cuda_12.6.0_560.28.03_linux.run

# Install (driver already installed, so skip driver)
sudo sh cuda_12.6.0_560.28.03_linux.run --silent --toolkit --override

# Set environment variables
echo 'export PATH=/usr/local/cuda-12.6/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc
```

Verify:
```bash
nvcc --version  # Should show CUDA 12.6
```

## Step 3: Install Build Dependencies

```bash
# Essential build tools
sudo apt update
sudo apt install -y build-essential git python3-pip python3-venv cmake ninja-build pkg-config libopenblas-dev

# Install GCC 11 (for compatibility)
sudo apt install -y gcc-11 g++-11
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 110
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 110
```

## Step 4: Install SGLang from Source

```bash
# Clone SGLang repository
cd ~
git clone https://github.com/sgl-project/sglang.git
cd sglang

# Create Python virtual environment
python3 -m venv sglang-env
source sglang-env/bin/activate

# Upgrade pip
pip install --upgrade pip setuptools wheel

# Install PyTorch with CUDA 12.6 support
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126

# Install FlashInfer
pip install flashinfer -i https://flashinfer.ai/whl/cu126/torch2.5/

# Build and install SGLang from source
pip install -e "python[all]"

# Install additional dependencies
pip install fastapi uvicorn httpx
```

## Step 5: Critical Blackwell Configuration

### The Three Critical Flags

**CRITICAL**: Blackwell GPUs require these three configurations:

1. **`TORCH_CUDA_ARCH_LIST='12.0+PTX'`** - Environment variable for CUDA compiler
2. **`--attention-backend triton`** - Use Triton instead of FlashInfer
3. **`--disable-cuda-graph`** - Disable CUDA graph optimization

### Why These Are Required

**`TORCH_CUDA_ARCH_LIST='12.0+PTX'`**
- Tells PyTorch/CUDA compiler to target compute capability 12.0 (Blackwell)
- Without this: `nvcc fatal: Unsupported gpu architecture 'compute_120a'`

**`--attention-backend triton`**
- FlashInfer's MergeState kernel has compatibility issues with Blackwell
- Triton is stable but ~10-15% slower

**`--disable-cuda-graph`**
- CUDA graphs fail to compile for Blackwell in current PyTorch
- Without this: process killed at ~45s during kernel compilation

### Startup Script

```bash
cat > ~/start_sglang.sh << 'SCRIPT'
#!/bin/bash

# Blackwell CUDA architecture fix
export TORCH_CUDA_ARCH_LIST='12.0+PTX'

# CUDA paths
export PATH=/usr/local/cuda-12.6/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:$LD_LIBRARY_PATH

# Activate SGLang environment
cd ~/sglang
source sglang-env/bin/activate

# Launch SGLang with Blackwell-compatible flags
python -m sglang.launch_server \
    --model-path "$1" \
    --port 30000 \
    --host 0.0.0.0 \
    --attention-backend triton \
    --disable-cuda-graph
SCRIPT

chmod +x ~/start_sglang.sh
```

## Step 6: Test Installation

```bash
# Test with a model
~/start_sglang.sh /path/to/your/model

# In another terminal
curl http://localhost:30000/v1/models
```

## Troubleshooting

### Process killed after ~45 seconds
**Cause**: Insufficient system RAM during CUDA kernel compilation  
**Solution**: Increase RAM to 128GB+

### `nvcc fatal: Unsupported gpu architecture`
**Cause**: Missing `TORCH_CUDA_ARCH_LIST` environment variable  
**Solution**: Ensure `export TORCH_CUDA_ARCH_LIST='12.0+PTX'` is set

### MergeState kernel error
**Cause**: FlashInfer incompatibility  
**Solution**: Use `--attention-backend triton`

### CUDA graph capture failed
**Cause**: CUDA graph not supported on Blackwell yet  
**Solution**: Use `--disable-cuda-graph`

## Performance Notes

- **Throughput**: 400-550 tok/s output (Mistral-Large-2411-AWQ)
- **Memory**: ~37GB for 70B AWQ + 44GB KV cache
- **Startup**: 60-90 seconds for large models

## Verified Working Configuration

- **Ubuntu**: 24.04 LTS
- **Driver**: 580.95.05 (open kernel)
- **CUDA**: 12.6
- **GPU**: RTX PRO 6000 Blackwell (97.9 GB VRAM)
- **RAM**: 128 GB
- **Models tested**: DeepSeek-R1-Distill-Llama-70B-AWQ

---
**Last updated**: January 26, 2025
