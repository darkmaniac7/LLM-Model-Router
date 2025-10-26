# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is a production-ready FastAPI-based router that enables seamless switching between multiple LLM inference backends (SGLang, TabbyAPI, llama.cpp). It acts as an OpenAI-compatible API gateway on port 8002, automatically managing backend services, streaming status updates during model switches, and appending real-time performance metrics (tok/s) to responses.

**Key Value Proposition**: Solves the limitation that backends like SGLang/vLLM/TabbyAPI can only serve one model at a time, enabling Open-WebUI users to switch between models from a dropdown without manual service restarts.

## Architecture

### Core Components

**router.py** - Main application with three key responsibilities:
1. **Model Switching Logic**: Detects when a different backend is needed, stops the current service, updates systemd service configs (for SGLang/llama.cpp) or config.yml (for TabbyAPI), restarts services with new model
2. **Streaming Status Updates**: Yields SSE messages during model loading (🔄 Switching → ⏳ Loading... Xs/180s → ✅ Ready!)
3. **Request Forwarding**: Proxies chat completion requests to the active backend with performance tracking

**Backend Support**:
- **SGLang** (port 30000): AWQ quantized models, switched via systemd ExecStart script updates
- **TabbyAPI** (port 5000): EXL2 quantized models, switched via config.yml model_name updates with 3s shutdown wait + 5s warmup
- **llama.cpp** (port 8085): GGUF quantized models, switched via systemd ExecStart script updates

**Model Configuration** (MODELS dict in router.py):
```python
{
    "model-id": {
        "backend": "sglang|tabby|llamacpp",
        "script": "/path/to/startup_script.sh",  # for sglang/llamacpp
        "service": "backend.service",
        "model_name": "Model-Dir-Name"  # TabbyAPI only
    }
}
```

### Service Management Pattern

The router uses systemd service restarts (not API-based model loading) because:
- Provides clean state on every switch
- Prevents stuck/orphaned processes
- TabbyAPI's API-based model loading proved unreliable (truncated responses)
- SGLang doesn't support runtime model switching

**TabbyAPI Switching Sequence**:
1. Stop all backend services
2. Wait 3s for clean shutdown (critical to prevent file locks)
3. Update TabbyAPI `config.yml` with new model_name (searches ~/tabbyAPI/, /opt/tabbyAPI/, /etc/tabbyapi/)
4. Start TabbyAPI service
5. Wait for health check + 5s warmup (prevents truncated responses)

## Common Commands

### Development
```bash
# Run router directly (for development)
python3 router.py

# Install dependencies
pip install fastapi uvicorn httpx pyyaml
```

### Testing
```bash
# List available models
curl http://localhost:8002/v1/models

# Health check
curl http://localhost:8002/health

# Test streaming chat
curl -X POST http://localhost:8002/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral-large-2411-awq",
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": true
  }'
```

### Production Deployment
```bash
# Install with interactive prompts
sudo ./install.sh

# Service management
sudo systemctl start llm-router
sudo systemctl stop llm-router
sudo systemctl status llm-router
sudo systemctl enable llm-router  # auto-start on boot

# View logs
sudo journalctl -u llm-router -f

# Check backend services
sudo systemctl status sglang
sudo systemctl status tabbyapi
sudo systemctl status llamacpp
```

### Configuration Files
```bash
# Edit router configuration (backend ports, timeouts)
sudo nano /etc/llm-router/config.yml

# Edit model definitions (what models are available)
sudo nano /etc/llm-router/models.yml

# Reload after config changes
sudo systemctl restart llm-router
```

## Key Implementation Details

### Concurrency Control
- Uses `asyncio.Lock()` (switching_lock) to prevent concurrent model switches
- Global `current_model` variable tracks active model to avoid unnecessary switches

### Performance Metrics
- Tracks token count during streaming by parsing SSE chunks (rough estimate: ~4 chars per token)
- Calculates tok/s = tokens / elapsed_time
- Appends "⚡ X.X tok/s (~N tokens in X.Xs)" to responses
- Non-streaming responses use backend's usage.completion_tokens if available

### Health Checks
- Each backend has a health endpoint (`/health`)
- `wait_for_backend_ready_streaming()` polls every 2s with 180s timeout
- Yields status updates every 10s for UX feedback
- For TabbyAPI: health check pass + 5s warmup before declaring ready

### Error Handling
- Model switch failures yield error SSE messages but don't crash the router
- Timeouts after 180s with clear error messaging
- HTTP exceptions for unknown models (400) and switch failures (503)

## Backend-Specific Notes

### llama.cpp Setup
- Must be compiled with CUDA support for GPU acceleration
- For Blackwell GPUs (sm_90): `cmake -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=90`
- Startup scripts use `-ngl 999` to offload all layers to GPU
- Port 8085 by default, health endpoint at `/health`

### TabbyAPI Quirks
- Config file locations checked: `~/tabbyAPI/config.yml`, `/opt/tabbyAPI/config.yml`, `/etc/tabbyapi/config.yml`
- Updates the model.model_name field in config.yml
- Requires YAML library: `pip install pyyaml`
- Service restart method is MORE reliable than API-based model loading
- 5s warmup critical: prevents first response truncation

### SGLang
- Uses per-model startup scripts that specify --model-path
- Service config updated via sed: `sed -i 's|ExecStart=.*|ExecStart=/path/to/script.sh|'`
- Requires `systemctl daemon-reload` after service file changes

## Open-WebUI Integration

**Setup**:
1. In Open-WebUI Settings → Connections
2. Set API URL: `http://localhost:8002/v1`
3. API Key: (any value or leave empty)
4. All configured models appear in model dropdown

**User Experience**:
- Select different model from dropdown → router automatically switches
- Chat window shows: "🔄 Switching to model-name..." → loading progress → "✅ Model ready!"
- Normal chat response streams with "⚡ tok/s" appended at end

## Installation Pattern

The `install.sh` script:
1. Detects Python 3.10+ (tries python3.12, python3.11, python3.10, python3)
2. Prompts interactively for install dir, ports, backend details
3. Creates Python venv at specified location
4. Installs dependencies: fastapi, uvicorn, httpx, pyyaml
5. Generates config files in `/etc/llm-router/`
6. Creates systemd service at `/etc/systemd/system/llm-router.service`
7. User must manually edit `/etc/llm-router/models.yml` to add models

## Development Guidelines

### Adding New Models
Edit MODELS dict in router.py or models.yml (if using installed version):
- SGLang/llama.cpp: provide script path and service name
- TabbyAPI: provide model_name (directory name in models folder) and service name

### Adding New Backends
1. Add backend URL constant (e.g., NEWBACKEND_URL)
2. Add health check case in `get_backend_health()`
3. Create `switch_to_newbackend_model_streaming()` generator function
4. Add backend case in `streaming_chat_with_model_switch()`
5. Update backend_url routing logic
6. Update health endpoint to include new backend

### Performance Optimization Notes
- Current bottleneck on Blackwell GPUs: immature sm_120 kernels
- FlashAttention-4 for sm_120 not yet available (when released: expect 50-65 tok/s)
- Current performance: AWQ (SGLang) 22-25 tok/s, EXL2 (TabbyAPI) 17-18 tok/s

## Target Environment

**Operating System**: Ubuntu/Debian Linux (systemd-based)
**Python**: 3.10+
**Dependencies**: FastAPI, httpx, uvicorn, pyyaml
**Privileges**: Root/sudo required for systemd service management
**Network**: Backends must be accessible on localhost

## Version History Context

- **v3.2.0**: Added llama.cpp support, improved Blackwell GPU compatibility
- **v3.1.1**: Added tok/s metrics, improved TabbyAPI reliability with warmup
- **v3.0.0**: Initial multi-backend support (SGLang + TabbyAPI)

Current production version uses service restart approach after determining API-based switching was unreliable for TabbyAPI.
