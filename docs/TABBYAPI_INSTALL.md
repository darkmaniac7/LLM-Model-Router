# TabbyAPI Installation Guide for LLM Router

## Overview

TabbyAPI (EXL2 backend) requires flash-attention 2.5.7+ which is challenging to build on NVIDIA Blackwell GPUs. This guide provides two approaches.

## ⚠️ Critical Requirements

- Working venv with flash-attn 2.8.3+ (pre-built recommended)
- exllamav2 0.3.2+
- Python 3.10-3.12
- NVIDIA GPU with 40GB+ VRAM for 70B models

## Method 1: Copy Working venv (Recommended)

If you have access to a working TabbyAPI installation with flash-attn already built:

```bash
# On working server - create tarball
cd /home/ivan
tar -czf tabbyapi-venv.tar.gz TabbyAPI/venv/

# Transfer to new server
scp tabbyapi-venv.tar.gz user@newserver:/tmp/

# On new server - extract
cd /home/ivan/TabbyAPI
tar -xzf /tmp/tabbyapi-venv.tar.gz

# CRITICAL: Make python executable
chmod +x venv/bin/python*

# Verify
venv/bin/python --version
venv/bin/python -c "import flash_attn; print(flash_attn.__version__)"
```

## Method 2: Build from Scratch

### Install TabbyAPI

```bash
cd ~
git clone https://github.com/theroyallab/tabbyAPI TabbyAPI
cd TabbyAPI
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

###  Install flash-attn (Blackwell GPU)

**Note**: Building flash-attn on Blackwell GPUs may fail. Try prebuilt wheel first:

```bash
# Try prebuilt wheel
pip install https://github.com/Dao-AILab/flash-attention/releases/download/v2.8.3/flash_attn-2.8.3+cu124torch2.5cxx11abiFALSE-cp312-cp312-linux_x86_64.whl

# OR build from source (use compute_89,90 workaround)
export TORCH_CUDA_ARCH_LIST="8.9;9.0"
MAX_JOBS=4 pip install flash-attn==2.8.3 --no-build-isolation
```

If build fails, you MUST use Method 1 (copy working venv).

## Configuration

### 1. Create config.yml

```bash
cd /home/ivan/TabbyAPI
cat > config.yml << 'YAML_EOF'
developer:
  backend: exllamav2
  unsafe_launch: false

logging:
  log_generation_params: false
  log_prompt: false
  log_requests: false

model:
  cache_mode: FP16
  cache_size: 32768
  chunk_size: 4096
  gpu_split_auto: true
  max_batch_size: 1
  max_seq_len: 32768
  model_dir: /home/ivan/models
  model_name: exl2/YourModelName
  tensor_parallel: false

network:
  api_servers:
  - OAI
  disable_auth: true
  host: 0.0.0.0
  port: 5000
YAML_EOF
```

**CRITICAL**: Use `model_dir` (parent directory) + `model_name` (subdirectory) format!

### 2. Create api_tokens.yml

```bash
# TabbyAPI will auto-generate keys on first start
# Just create empty file
echo "" > api_tokens.yml
```

After first start, TabbyAPI will populate with:
```yaml
admin_key: <generated-key>
api_key: <generated-key>
```

### 3. Create systemd service

```bash
sudo tee /etc/systemd/system/tabbyapi.service > /dev/null << 'SERVICE_EOF'
[Unit]
Description=TabbyAPI Server - EXL2 Backend
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/ivan/TabbyAPI
ExecStart=/home/ivan/TabbyAPI/venv/bin/python main.py
Restart=no
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

sudo systemctl daemon-reload
```

## Testing

```bash
# Start TabbyAPI
sudo systemctl start tabbyapi.service

# Wait 60-90 seconds for model to load
sleep 90

# Check GPU usage (should show ~40-50GB for 70B models)
nvidia-smi

# Test health endpoint
curl http://localhost:5000/health

# Check API keys in logs
sudo journalctl -u tabbyapi.service | grep "admin key"
```

## Integration with Router

The router automatically:
1. Reads `api_tokens.yml` for health checks
2. Updates `model_name` in config.yml when switching models
3. Restarts tabbyapi.service via systemd

No manual configuration needed!

## Troubleshooting

### Model won't load
```bash
# Check logs
sudo journalctl -u tabbyapi.service -n 100

# Common issues:
# - Wrong model path (must be model_dir + model_name)
# - Missing flash-attn
# - Insufficient GPU memory
```

### flash-attn build fails
```bash
# Check CUDA version
nvcc --version  # Need 12.4+

# Check if flash-attn installed
/home/ivan/TabbyAPI/venv/bin/python -c "import flash_attn; print(flash_attn.__version__)"

# If missing, use Method 1 (copy working venv)
```

### API key errors
```bash
# Ensure both keys exist in api_tokens.yml
cat /home/ivan/TabbyAPI/api_tokens.yml

# Should have:
# admin_key: xxx
# api_key: xxx

# If missing, delete and restart to regenerate
rm /home/ivan/TabbyAPI/api_tokens.yml
sudo systemctl restart tabbyapi.service
```

## Model Path Format

TabbyAPI expects:
- `model_dir`: `/home/ivan/models`
- `model_name`: `exl2/ModelName`

Combined path: `/home/ivan/models/exl2/ModelName`

The router config uses just the subdirectory path:
```json
{
  "model_path": "exl2/ModelName"
}
```

Router automatically updates `model_name` field in config.yml when switching.

---

**Version**: 4.0.0  
**Status**: Tested on Blackwell GPUs ✅
