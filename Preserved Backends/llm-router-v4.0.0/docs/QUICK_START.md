# Quick Start Guide

## Prerequisites

- Ubuntu 22.04+
- NVIDIA GPU with CUDA 12.4+
- Python 3.10+
- 64GB+ RAM recommended

## Installation

### 1. Install Router

```bash
# Create directory
sudo mkdir -p /opt/llm-router
cd /opt/llm-router

# Copy router.py
sudo cp router.py /opt/llm-router/

# Create venv
sudo python3 -m venv venv
sudo venv/bin/pip install fastapi uvicorn httpx pyyaml

# Create config
sudo cp config/config.json.example /opt/llm-router/config.json
# Edit config.json with your model paths

# Install systemd service
sudo cp systemd/llm-router.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable llm-router.service
```

### 2. Install Backends

Choose the backends you need:

#### SGLang (AWQ models)
```bash
cd ~
git clone https://github.com/sgl-project/sglang
cd sglang
python -m venv sglang-env
source sglang-env/bin/activate
export TORCH_CUDA_ARCH_LIST="8.9;9.0"  # For Blackwell
pip install -e "python[all]"
```

#### llama.cpp (GGUF models)
```bash
cd ~
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
mkdir build && cd build
cmake .. -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES="89;90"
cmake --build . --config Release -j$(nproc)
```

#### TabbyAPI (EXL2 models)
See `docs/TABBYAPI_INSTALL.md` for detailed guide.

### 3. Start Router

```bash
sudo systemctl start llm-router.service
sudo systemctl status llm-router.service
```

### 4. Test

```bash
# List models
curl http://localhost:8002/v1/models

# Chat
curl -X POST http://localhost:8002/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "your-model", "messages": [{"role": "user", "content": "Hi"}]}'
```

## Configuration

Edit `/opt/llm-router/config.json`:

```json
{
  "models": {
    "model-name": {
      "backend": "sglang|llamacpp|tabbyapi",
      "model_path": "/path/to/model"
    }
  }
}
```

For TabbyAPI models, use subdirectory format:
```json
"model_path": "exl2/ModelName"
```

## Monitoring

```bash
# Check services
sudo systemctl status llm-router.service
sudo systemctl status tabbyapi.service
sudo systemctl status sglang.service
sudo systemctl status llamacpp.service

# View logs
sudo journalctl -u llm-router.service -f

# GPU usage
nvidia-smi
```

## Troubleshooting

See main README.md for detailed troubleshooting.
