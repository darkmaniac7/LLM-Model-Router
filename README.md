**Multi-Backend LLM Router v4.0.0**

Production-ready router supporting **SGLang (AWQ)**, **llama.cpp (GGUF)**, and **TabbyAPI (EXL2)** with automatic model switching through a unified OpenAI-compatible API.

**Features**

- **3 Backend Support**: Seamlessly switch between GGUF, AWQ, and EXL2 models
- **Automatic Model Switching**: Router handles backend lifecycle
- **Systemd Management**: Reliable service control with proper monitoring
- **Health Monitoring**: Intelligent checks with actual inference validation
- **Streaming Support**: Full streaming for all backends
- **Performance Metrics**: Real-time tokens/sec display after each response
- **OpenAI Compatible**: Drop-in replacement for OpenAI API

**Quick Start**

```bash
# 1. Clone repository
git clone https://github.com/darkmaniac7/LLM-Model-Router.git
cd LLM-Model-Router

# 2. Install router
sudo mkdir -p /opt/llm-router
sudo cp router.py /opt/llm-router/
sudo python3 -m venv /opt/llm-router/venv
sudo /opt/llm-router/venv/bin/pip install fastapi uvicorn httpx pyyaml

# 3. Configure
sudo cp config/config.json.example /opt/llm-router/config.json
# Edit /opt/llm-router/config.json with your model paths

# 4. Install service
sudo cp systemd/llm-router.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now llm-router.service

# 5. Test
curl http://localhost:8002/v1/models
```

**Documentation**

- **[Quick Start Guide](docs/QUICK_START.md)** - Get running in 10 minutes
- **[TabbyAPI Installation](docs/TABBYAPI_INSTALL.md)** - Complete EXL2 backend setup
- **[Configuration Examples](config/)** - Sample configs for all backends

Backends

| Backend | Format | Best For | Memory |
|---------|--------|----------|--------|
| **SGLang** | AWQ | Fast inference, high throughput | Medium-High |
| **llama.cpp** | GGUF | CPU/GPU hybrid, flexibility | Low-Medium |
| **TabbyAPI** | EXL2 | Maximum quality, NVIDIA only | High |

**Requirements**

- Ubuntu 22.04+ or compatible Linux
- NVIDIA GPU with CUDA 12.4+
- Python 3.10+
- 64GB+ RAM (for 70B models)
- Root access for systemd services

**Usage**

List Models

```bash
curl http://localhost:8002/v1/models
```

Chat Completion

```bash
curl -X POST http://localhost:8002/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "your-model-name",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 100
  }'
```

Health Check

```bash
curl http://localhost:8002/health
```

**Performance Metrics**

The router automatically displays performance stats after each response:

```
Your response text here...

⚡ 45.2 tok/s (180 tokens in 4.0s)
```

## 🛠️ Installation Scripts

### Interactive Installer (`install.sh`)

The included installer script automates the entire setup process:

```bash
sudo ./install.sh
```

**What it does:**

1. **Detects Python** - Finds Python 3.10+ automatically
2. **Prompts for Configuration**:
   - Install directory (default: `/opt/llm-router`)
   - Router port (default: `8002`)
   - Backend hosts and ports (SGLang, llama.cpp, TabbyAPI)
   - TabbyAPI paths (install dir, model directory)
3. **Creates Virtual Environment** - Installs all Python dependencies
4. **Generates Config** - Creates `/opt/llm-router/config.json` with your settings
5. **Installs Systemd Service** - Sets up `llm-router.service` with proper environment variables
6. **Copies Management Script** - Installs `manage-models.sh` for easy model management

**Example Prompts:**
```
Install directory [/opt/llm-router]: 
Router port [8002]: 
SGLang port [30000] (empty to disable): 
llama.cpp port [8085] (empty to disable): 
TabbyAPI port [5000] (empty to disable): 
TabbyAPI install directory [/opt/TabbyAPI]: 
Model directory [/opt/models]: 
```

The installer creates a complete, ready-to-run setup with all paths configured correctly.

### Model Management Script (`manage-models.sh`)

Easy model management without manual JSON editing:

```bash
# Interactive menu
/opt/llm-router/manage-models.sh

# Or use directly
/opt/llm-router/manage-models.sh list    # List all configured models
/opt/llm-router/manage-models.sh add     # Add a new model
/opt/llm-router/manage-models.sh remove  # Remove a model
```

**Add a Model (Interactive):**

1. **Choose name**: `my-llama-70b`
2. **Select backend**:
   - `1) llama.cpp (for GGUF models)`
   - `2) sglang (for AWQ models)`
   - `3) tabbyapi (for EXL2 models)`
3. **Enter path**: `/opt/models/gguf/llama-70b-q4.gguf`
4. **Restart router**: `y/n`

The script automatically:
- Updates `/opt/llm-router/config.json`
- Validates JSON format
- Offers to restart the router service
- Shows current models with `list` command

**Example Output:**
```
Current Models:

  • my-llama-70b
    Backend: llamacpp
    Path: /opt/models/gguf/llama-70b-q4.gguf

  • deepseek-awq
    Backend: sglang
    Path: /opt/models/awq/DeepSeek-R1-70B
```

## Configuration

Router Config (`/opt/llm-router/config.json`)

```json
{
  "router_port": 8002,
  "model_load_timeout": 300,
  "backends": {
    "sglang": {"port": 30000, "host": "localhost"},
    "llamacpp": {"port": 8085, "host": "localhost"},
    "tabbyapi": {"port": 5000, "host": "localhost"}
  },
  "models": {
    "your-gguf-model": {
      "backend": "llamacpp",
      "model_path": "/path/to/model.gguf"
    },
    "your-awq-model": {
      "backend": "sglang",
      "model_path": "/path/to/awq-model"
    },
    "your-exl2-model": {
      "backend": "tabbyapi",
      "model_path": "exl2/ModelName"
    }
  }
}
```

**Note**: TabbyAPI uses `model_dir` + `model_name` format. The router path should be the subdirectory only (e.g., `"exl2/ModelName"`).

**Monitoring**

```bash
# Check router
sudo systemctl status llm-router.service

# Check backends
sudo systemctl status sglang.service
sudo systemctl status llamacpp.service
sudo systemctl status tabbyapi.service

# View logs
sudo journalctl -u llm-router.service -f

# GPU usage
nvidia-smi
```

**Troubleshooting**

### Router not responding
```bash
# Check if running
sudo systemctl status llm-router.service

# View logs
sudo journalctl -u llm-router.service -n 50

# Restart
sudo systemctl restart llm-router.service
```

Backend not loading
```bash
# Check backend status
sudo systemctl status tabbyapi.service

# Test backend directly
curl http://localhost:5000/health  # TabbyAPI
curl http://localhost:30000/health # SGLang
curl http://localhost:8085/health  # llama.cpp
```

Model switching fails
- Check `MODEL_LOAD_TIMEOUT` in config (default: 300s)
- Verify model paths are correct
- Check GPU has sufficient memory (`nvidia-smi`)

TabbyAPI auth errors
Router automatically reads `api_tokens.yml`. Ensure it exists:
```bash
cat $TABBY_TOKENS_PATH
# Should have both admin_key and api_key
# Default path: /opt/TabbyAPI/api_tokens.yml
```

**Advanced**

Multiple GPUs

**TabbyAPI**: Set `gpu_split_auto: true` in config.yml  
**SGLang**: Use `--tensor-parallel-size N`  
**llama.cpp**: Use `-ngl 999` to offload all layers

Custom Parameters

Edit backend startup commands in systemd service files.

Blackwell GPU Support

Tested on NVIDIA RTX PRO 6000 Blackwell. Use these build flags:

- **SGLang**: `TORCH_CUDA_ARCH_LIST="8.9;9.0"`
- **llama.cpp**: `CMAKE_CUDA_ARCHITECTURES="89;90"`
- **TabbyAPI**: Use pre-built venv with flash-attn (see docs)

**Architecture**

```
Client → Router (8002)
           ↓
    ┌──────┴──────┐
    ↓      ↓      ↓
 SGLang  llama  TabbyAPI
 (30000) (8085) (5000)
   AWQ    GGUF    EXL2
```

**Contributing**

Contributions welcome! Please open an issue or PR on GitHub.

License

MIT License

**Acknowledgments**

- [SGLang](https://github.com/sgl-project/sglang) - Fast AWQ inference
- [llama.cpp](https://github.com/ggerganov/llama.cpp) - GGUF support
- [TabbyAPI](https://github.com/theroyallab/tabbyAPI) - EXL2 backend

---

**Version**: 4.0.0  
**Status**: Production Ready ✅  
**Tested**: NVIDIA Blackwell GPUs  
**Last Updated**: October 26, 2025
