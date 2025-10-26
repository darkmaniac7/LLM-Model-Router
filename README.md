**Multi-Backend LLM Router v4.0.0**

Production-ready router supporting **SGLang (AWQ)**, **llama.cpp (GGUF)**, and **TabbyAPI (EXL2)** with automatic model switching through a unified OpenAI-compatible API.

**Features**

- **3 Backend Support**: Seamlessly switch between GGUF, AWQ, and EXL2 models
- **Automatic Model Switching**: Router handles backend lifecycle
- **Systemd Management**: Reliable service control with proper monitoring
- **Health Monitoring**: Intelligent checks with actual inference validation
- **Streaming Support**: Full streaming for all backends
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

**Configuration**

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
