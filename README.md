# Multi-Backend LLM Router

**Version 3.2.0** - Now with llama.cpp support!

A production-ready FastAPI-based router for seamlessly switching between multiple LLM backends:
- **SGLang** (AWQ quantized models)
- **TabbyAPI** (EXL2 quantized models)  
- **llama.cpp** (GGUF quantized models)

Perfect for Blackwell GPUs and Open-WebUI integration with real-time streaming status updates and token-per-second performance metrics.

## Features

✅ **Multi-Backend Support**: SGLang (AWQ), TabbyAPI (EXL2), llama.cpp (GGUF)  
✅ **Automatic Model Switching**: Seamless backend transitions with streaming status  
✅ **Real-Time Metrics**: Token/s performance tracking appended to responses  
✅ **Production Ready**: Systemd services, health checks, timeout handling  
✅ **Open-WebUI Compatible**: Drop-in replacement for OpenAI API  
✅ **Blackwell Optimized**: Tested on RTX 6000 Pro Blackwell

## Quick Start

### Prerequisites

- Ubuntu/Debian Linux
- Python 3.10+
- One or more backends:
  - SGLang (for AWQ models)
  - TabbyAPI (for EXL2 models)
  - llama.cpp (for GGUF models)

### Installation

```bash
# Download and extract
tar -xzf multi-backend-llm-router.tar.gz
cd multi-backend-llm-router

# Run interactive installer
sudo ./install.sh
```

The installer will:
1. Check dependencies (Python, systemd)
2. Create virtual environment and install packages
3. Configure router with your backend settings
4. Set up systemd services
5. Start the router

### Manual Configuration

Edit `config/router_config.json` to add your models:

```json
{
  "router_port": 8002,
  "backends": {
    "sglang": {"port": 30000},
    "tabbyapi": {"port": 5000},
    "llamacpp": {"port": 8085}
  },
  "models": {
    "mistral-large-awq": {
      "backend": "sglang",
      "script": "/path/to/start_mistral.sh",
      "service": "sglang.service"
    },
    "behemoth-123b-iq4nl": {
      "backend": "llamacpp",
      "script": "/path/to/start_behemoth.sh",
      "service": "llamacpp.service"
    }
  }
}
```

**Important**: Replace `/path/to/` with your actual installation paths. Example startup scripts in the `scripts/` directory use environment variables that expand to your home directory automatically.

## Backend Setup

### llama.cpp (GGUF Models)

Build llama.cpp with CUDA support:

```bash
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
mkdir build && cd build

# For Blackwell GPUs (sm_90)
cmake .. -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=90 \
         -DCMAKE_BUILD_TYPE=Release \
         -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc \
         -DCMAKE_CUDA_FLAGS="-allow-unsupported-compiler"

cmake --build . --config Release -j $(nproc)
```

Create startup script (example):

```bash
#!/bin/bash
cd /path/to/llama.cpp/build
exec ./bin/llama-server \
    -m /path/to/model.gguf \
    -ngl 999 \
    --port 8085 \
    --host 0.0.0.0 \
    -c 4096
```

### SGLang (AWQ Models)

```bash
pip install "sglang[all]"
```

Create startup script:
```bash
#!/bin/bash
python -m sglang.launch_server \
    --model-path /path/to/awq/model \
    --port 30000 \
    --host 0.0.0.0
```

### TabbyAPI (EXL2 Models)

```bash
git clone https://github.com/theroyallab/tabbyAPI
cd tabbyAPI
pip install -r requirements.txt
```

Configure in `config.yml` and create service.

## Usage

### With Open-WebUI

1. Add the router as a connection:
   ```
   http://localhost:8002/v1
   ```

2. Select any model from the dropdown - router handles backend switching automatically

### Direct API

```bash
# List models
curl http://localhost:8002/v1/models

# Chat completion
curl http://localhost:8002/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "behemoth-123b-iq4nl",
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": true
  }'
```

## Model Switching

The router automatically:
1. Detects when a different backend is needed
2. Stops the current backend service
3. Starts the new backend with the requested model
4. Streams loading status to the client
5. Forwards requests once ready

Loading status example:
```
⏳ Loading model... 15s / 180s
✓ Model ready! (23s)
```

## Performance Metrics

Token/s stats are automatically appended to responses:
```
Your response text here.

[Performance: 45.2 tok/s | 128 tokens in 2.83s]
```

## Troubleshooting

### Check router status
```bash
sudo systemctl status llm-router
sudo journalctl -u llm-router -f
```

### Check backend status
```bash
sudo systemctl status sglang
sudo systemctl status tabbyapi
sudo systemctl status llamacpp
```

### Test health endpoint
```bash
curl http://localhost:8002/health
```

## File Structure

```
multi-backend-llm-router/
├── install.sh              # Interactive installer
├── router.py               # Main router application
├── README.md               # This file
├── LICENSE                 # MIT License
├── config/
│   └── router_config.json.template
├── systemd/
│   ├── llm-router.service.template
│   └── llamacpp.service.template
└── scripts/
    └── (model startup scripts go here)
```

## Configuration Reference

### Router Configuration

`router_port`: Port for the router API (default: 8002)  
`model_load_timeout`: Max seconds to wait for model load (default: 180)

### Model Configuration

Each model requires:
- `backend`: "sglang", "tabbyapi", or "llamacpp"
- `script`: Path to startup script for the model
- `service`: Systemd service name for the backend
- `model_name`: (TabbyAPI only) Model directory name

## Requirements

- Python 3.10+
- FastAPI
- httpx
- uvicorn
- pyyaml (for TabbyAPI support)

Installed automatically by `install.sh`

## Version History

**3.2.0** (2025-10-25)
- Added llama.cpp support for GGUF models
- Improved Blackwell GPU compatibility
- Enhanced startup scripts

**3.1.1** (2025-10-24)
- Added tok/s performance metrics
- Improved TabbyAPI model switching reliability
- Better warmup handling

**3.0.0** (2025-10-23)
- Initial multi-backend support
- SGLang and TabbyAPI integration
- Streaming status updates

## License

MIT License - See LICENSE file

## Support

For issues and updates: https://github.com/yourusername/multi-backend-llm-router

---

**Pro Tip**: For best results with llama.cpp on Blackwell GPUs, use IQ4_NL or Q4_K_M quantizations for 123B models. They offer excellent quality while fitting in 48GB VRAM.
