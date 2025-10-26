# SGLang Multi-Model Router for OpenWebUI

An intelligent router system that allows seamless switching between multiple large language models through OpenWebUI's interface.

## Architecture Overview

### The Problem
- You have multiple 70B-123B models
- Each requires 4x GPUs (80-100GB VRAM total)
- You can only run ONE model at a time
- You want seamless switching in OpenWebUI without manual intervention

### The Solution
This router acts as a smart proxy that:
1. Presents all available models to OpenWebUI
2. Automatically detects when you select a different model
3. Unloads the current model from GPU memory
4. Loads the requested model
5. Routes your request to the active model

## Components

### 1. Model Router (`model_router.py`)
- **Port**: 8002
- **Purpose**: OpenWebUI-compatible API endpoint with auto-switching
- **Features**:
  - Lists all available models via `/v1/models`
  - Handles chat completions via `/v1/chat/completions`
  - Automatically switches models when needed
  - Waits for model loading before routing requests

### 2. SGLang Backend Service (`sglang.service`)
- **Port**: 8001
- **Purpose**: Runs the actual LLM inference
- **Managed By**: systemd
- **Features**:
  - Controlled via `switch_model.sh` script
  - Automatically restarts when switching models
  - Runs on GPUs 1-4 with tensor parallelism

### 3. Model Startup Scripts
Each model has its own startup script in `/home/ivan/sglang/`:
- `start_sglang_mistral_tp4_compiled.sh` - Mistral Large Instruct 2411 AWQ
- `start_sglang_llama33_tp4_compiled.sh` - Llama 3.3 70B Instruct Abliterated AWQ  
- `start_sglang_deepseek_tp4_compiled.sh` - DeepSeek R1 Distill Llama 70B AWQ
- `start_sglang_glm_tp4_compiled.sh` - GLM 4.5 Air AWQ
- `start_sglang_magnum.sh` - Magnum v4 123B AWQ

**Common Configuration**:
- All use GPUs 1-4 (`CUDA_VISIBLE_DEVICES=1,2,3,4`)
- All serve on port 8001
- All use AWQ marlin quantization
- Tensor Parallelism = 4
- Context length = 16384-24576 tokens
- Memory fraction = 0.78-0.80

### 4. Model Switcher (`switch_model.sh`)
Manual model switching script that:
1. Updates the systemd service `ExecStart` path
2. Reloads systemd daemon
3. Restarts `sglang.service` (kills old model, starts new one)

**Usage**:
```bash
sudo /home/ivan/sglang/switch_model.sh mistral
sudo /home/ivan/sglang/switch_model.sh llama33
sudo /home/ivan/sglang/switch_model.sh deepseek
sudo /home/ivan/sglang/switch_model.sh glm
sudo /home/ivan/sglang/switch_model.sh magnum
```

## How It Works

### Request Flow
```
User selects model in OpenWebUI
         ↓
OpenWebUI sends request to router (port 8002)
         ↓
Router checks: Is requested model currently loaded?
         ├─ YES → Route request to SGLang (port 8001)
         └─ NO  → Trigger model switch
                  ├─ Call switch_model.sh
                  ├─ Wait for new model to load (~30-60 seconds)
                  └─ Route request to newly loaded model
```

### Model Switching Process
```
1. Router detects model change request
2. Router calls: subprocess.run(['/home/ivan/sglang/switch_model.sh', 'model_name'])
3. switch_model.sh updates systemd service file
4. systemd restarts sglang.service
   ├─ SIGTERM sent to current model process
   ├─ Model unloads from GPU (frees ~20GB x 4 GPUs)
   └─ New model process starts
5. New model loads into GPU memory (~30-60 seconds)
6. Router waits for health check success
7. Router routes the original request
```

## Installation

### Prerequisites
- Ubuntu Linux (tested on 22.04+)
- 4x NVIDIA GPUs with 24GB+ VRAM each
- CUDA 12.1+
- Python 3.10+
- Models downloaded to `/home/ivan/models/`

### Setup Steps

1. **Install SGLang**:
```bash
python3 -m venv /home/ivan/sglang/sglang-env
source /home/ivan/sglang/sglang-env/bin/activate
pip install "sglang[all]"
pip install fastapi uvicorn httpx
```

2. **Create systemd services**:
```bash
# Create sglang.service
sudo tee /etc/systemd/system/sglang.service << 'SGLANG_EOF'
[Unit]
Description=SGLang Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/ivan/sglang
ExecStart=/home/ivan/sglang/start_sglang_mistral_tp4_compiled.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SGLANG_EOF

# Create sglang-router.service  
sudo tee /etc/systemd/system/sglang-router.service << 'ROUTER_EOF'
[Unit]
Description=SGLang Model Router (Auto-Switching Proxy)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/ivan/sglang
ExecStart=/home/ivan/sglang/sglang-env/bin/python /home/ivan/sglang/model_router.py
Restart=always
RestartSec=10
StandardOutput=append:/home/ivan/sglang/router.log
StandardError=append:/home/ivan/sglang/router.log

[Install]
WantedBy=multi-user.target
ROUTER_EOF

# Reload and enable
sudo systemctl daemon-reload
sudo systemctl enable sglang.service sglang-router.service
```

3. **Start services**:
```bash
sudo systemctl start sglang.service
sudo systemctl start sglang-router.service
```

4. **Configure OpenWebUI**:
- Go to Settings → Connections
- Add OpenAI-compatible connection
- Base URL: `http://localhost:8002/v1`
- API Key: (leave blank or use dummy like `sk-local`)
- Save and refresh models list

## Configuration

### Adding New Models

1. **Create startup script** (`/home/ivan/sglang/start_sglang_newmodel.sh`):
```bash
#!/bin/bash
source /home/ivan/sglang/sglang-env/bin/activate
export CUDA_VISIBLE_DEVICES=1,2,3,4

/home/ivan/sglang/sglang-env/bin/python -m sglang.launch_server \
    --model-path /home/ivan/models/NewModel-AWQ \
    --host 0.0.0.0 \
    --port 8001 \
    --tp 4 \
    --context-length 24576 \
    --quantization awq_marlin \
    --served-model-name newmodel-awq \
    --mem-fraction-static 0.80 \
    --log-level info \
    --log-requests \
    --sleep-on-idle
```

2. **Add to switch_model.sh**:
```bash
case $MODEL in
    # ... existing models ...
    newmodel)
        SCRIPT="start_sglang_newmodel.sh"
        ;;
esac
```

3. **Add to model_router.py**:
```python
MODELS = {
    # ... existing models ...
    "newmodel-awq": {
        "endpoint": "http://localhost:8001",
        "name": "New Model AWQ"
    },
}
```

4. **Restart router**:
```bash
sudo systemctl restart sglang-router.service
```

## Monitoring

### Check Router Status
```bash
sudo systemctl status sglang-router.service
tail -f /home/ivan/sglang/router.log
```

### Check Model Server Status
```bash
sudo systemctl status sglang.service
sudo journalctl -u sglang.service -f
```

### Check Current Model
```bash
curl http://localhost:8001/get_model_info | jq .
```

### Test Router
```bash
# List models
curl http://localhost:8002/v1/models | jq .

# Health check
curl http://localhost:8002/health | jq .

# Test generation
curl -X POST http://localhost:8002/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral-large-2411-awq",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 50
  }' | jq .
```

## Troubleshooting

### Model Won't Switch
```bash
# Check if switch script is executable
chmod +x /home/ivan/sglang/switch_model.sh

# Check systemd service file
cat /etc/systemd/system/sglang.service

# Check for GPU memory issues
nvidia-smi
```

### Router Not Responding
```bash
# Check if router is running
ps aux | grep model_router

# Check for port conflicts
sudo lsof -i :8002

# Restart router
sudo systemctl restart sglang-router.service
```

### Model Loading Errors
```bash
# Check model path exists
ls -la /home/ivan/models/

# Check GPU availability
nvidia-smi

# Check logs for errors
sudo journalctl -u sglang.service -n 100
```

## Performance Notes

- **Model switching time**: 30-60 seconds
- **GPU memory per model**: ~20GB per GPU (80GB total for 4 GPUs)
- **Context length**: 16K-24K tokens depending on model
- **Throughput**: 15-25 tokens/second (varies by model and batch size)

## License

MIT License - Feel free to use and modify for your needs.

## Credits

Created for efficient multi-model serving with limited GPU resources.
