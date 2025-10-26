# Multi-Backend LLM Router Documentation

**Version:** 3.2.0  
**Last Updated:** 2025-10-25

## Overview

The Multi-Backend Router is a production-ready FastAPI application that seamlessly switches between different LLM backends while maintaining a single OpenAI-compatible API endpoint.

### Supported Backends

1. **SGLang** - AWQ quantized models (fastest)
2. **TabbyAPI** - EXL2 quantized models (flexible)
3. **llama.cpp** - GGUF quantized models (portable)

## Architecture

```
Open-WebUI → Router (Port 8002) → Backend Switch Logic
                                 ↓
                    ┌────────────┼────────────┐
                    ↓            ↓            ↓
                 SGLang      TabbyAPI    llama.cpp
              (Port 30000)  (Port 5000)  (Port 8085)
```

## Key Features

### Automatic Model Switching
- Detects requested model's backend
- Stops all running backends
- Starts correct backend with model
- Streams loading status to client
- Handles timeouts and errors

### Streaming Status Updates
```
⏳ Loading model... 15s / 180s
⏳ Loading model... 30s / 180s
✓ Model ready! (42s)
```

### Performance Metrics
Appends token/s stats to every response:
```
[Performance: 45.2 tok/s | 128 tokens in 2.83s]
```

### Backend Cleanup
- Stops all systemd services when switching
- Force-kills orphaned processes (llama-server)
- Prevents VRAM leaks

## Configuration

### Current Models (Blackwell Setup)

#### SGLang (AWQ) - 5 models
- `mistral-large-2411-awq`
- `llama-3.3-70b-awq`
- `deepseek-r1-distill-70b-awq`
- `magnum-v4-123b-awq`
- `kat-dev-awq-8bit`

#### TabbyAPI (EXL2) - 1 model
- `monstral-123b-exl2-4bpw`

#### llama.cpp (GGUF) - 2 models
- `behemoth-r1-123b-iq4nl` (Behemoth R1 123B IQ4_NL)
- `magnum-diamond-123b-iq4nl` (Magnum Diamond 123B IQ4_NL)

### Router Configuration Location

**Main Script:** `/home/ivan/model_router_blackwell.py`

**Service File:** `/etc/systemd/system/model-router.service`

**Startup Scripts:** `/home/ivan/sglang/*.sh`

### Adding New Models

Edit the MODELS dictionary in `model_router_blackwell.py`:

```python
MODELS = {
    "your-model-name": {
        "backend": "sglang",  # or "tabbyapi" or "llamacpp"
        "script": "/home/ivan/sglang/start_your_model.sh",
        "service": "sglang.service"  # or tabbyapi/llamacpp
    }
}
```

## Backend Details

### SGLang (Port 30000)

**Best for:** AWQ quantized models, highest throughput

**Service:** `sglang.service`

**Startup Script Example:**
```bash
#!/bin/bash
python -m sglang.launch_server --sleep-on-idle \
    --model-path /path/to/awq/model \
    --port 30000 \
    --host 0.0.0.0
```

**CPU Usage Fix:** All SGLang scripts now include `--sleep-on-idle` flag to prevent 350% idle CPU usage.

### TabbyAPI (Port 5000)

**Best for:** EXL2 quantized models, flexible quant sizes

**Service:** `tabbyapi.service`

**Config:** `/home/ivan/tabbyAPI/config.yml`

**Model Loading:** Router updates config.yml and restarts service

### llama.cpp (Port 8085)

**Best for:** GGUF quantized models, maximum portability

**Service:** `llamacpp.service`

**Startup Script Example:**
```bash
#!/bin/bash
cd /home/ivan/llama.cpp/build
exec ./bin/llama-server \
    -m /path/to/model.gguf \
    -ngl 999 \
    --port 8085 \
    --host 0.0.0.0 \
    -c 4096
```

**Built with:** CUDA 12.9, sm_90 (Blackwell), GCC 13

## Operations

### Starting the Router

```bash
sudo systemctl start model-router
```

### Checking Status

```bash
# Router status
sudo systemctl status model-router

# Current state
curl http://localhost:8002/health

# Available models
curl http://localhost:8002/v1/models
```

### Monitoring

```bash
# Real-time logs
sudo journalctl -u model-router -f

# Backend logs
sudo journalctl -u sglang -f
sudo journalctl -u tabbyapi -f
sudo journalctl -u llamacpp -f

# GPU usage
watch -n 1 nvidia-smi
```

### Restarting

```bash
sudo systemctl restart model-router
```

## Troubleshooting

### Model Won't Switch

**Symptom:** Loading status shows but model doesn't load

**Check:**
1. Backend service status: `systemctl status sglang`
2. Backend logs: `journalctl -u sglang -n 50`
3. VRAM availability: `nvidia-smi`
4. Script permissions: `ls -l /home/ivan/sglang/*.sh`

### Orphaned llama-server Process

**Symptom:** GPU memory still used after switching away

**Fix:**
```bash
pkill -9 llama-server
```

**Prevention:** Router v3.2.0+ automatically does this

### High CPU Usage (SGLang)

**Symptom:** 90-100% CPU per scheduler when idle

**Fix:** Ensure `--sleep-on-idle` in startup script

**Verify:**
```bash
grep "sleep-on-idle" /home/ivan/sglang/start_sglang_*_blackwell.sh
```

All scripts should show the flag. If not, add it:
```bash
python -m sglang.launch_server --sleep-on-idle \
    # ... rest of args
```

### Port Already in Use

**Symptom:** Router fails to start

**Fix:**
```bash
# Find process using port 8002
lsof -i :8002

# Kill it
kill <PID>

# Restart router
sudo systemctl restart model-router
```

### Backend Health Check Fails

**Check:**
```bash
# SGLang
curl http://localhost:30000/health

# TabbyAPI  
curl http://localhost:5000/health

# llama.cpp
curl http://localhost:8085/health
```

If fails, check service: `systemctl status <service-name>`

## Performance Tips

### VRAM Optimization

- **SGLang AWQ:** Most efficient, use when possible
- **TabbyAPI EXL2:** Flexible quant sizes (3.0-6.0 bpw)
- **llama.cpp GGUF:** IQ4_NL or Q4_K_M for 123B models

### Latency

- **First request after switch:** 20-60s (model loading)
- **Subsequent requests:** Normal latency
- **SGLang --sleep-on-idle:** Adds ~1-2ms on first request after idle

### CPU Usage

With `--sleep-on-idle`:
- **Idle:** 2-5% per scheduler
- **Active:** Normal CPU usage

Without flag:
- **Idle:** 90-100% per scheduler (avoid!)

## Integration with Open-WebUI

### Setup

1. In Open-WebUI, go to Settings → Connections
2. Add new connection:
   - **API Base URL:** `http://localhost:8002/v1`
   - **API Key:** (leave blank or any value)
3. Save and refresh models

### Usage

- Select any model from dropdown
- Router handles switching automatically
- Watch loading status in chat
- Performance stats appear in responses

## Files Reference

### Core Files
- `/home/ivan/model_router_blackwell.py` - Main router script
- `/etc/systemd/system/model-router.service` - Router service
- `/etc/systemd/system/sglang.service` - SGLang service
- `/etc/systemd/system/tabbyapi.service` - TabbyAPI service
- `/etc/systemd/system/llamacpp.service` - llama.cpp service

### Startup Scripts
- `/home/ivan/sglang/start_sglang_*_blackwell.sh` - SGLang models
- `/home/ivan/sglang/start_llamacpp_*_blackwell.sh` - GGUF models

### Logs
- Router: `journalctl -u model-router`
- Backends: `journalctl -u <service-name>`

## Version History

See `/tmp/multi-backend-llm-router/CHANGELOG.md` for details

## Support

For issues:
1. Check logs: `journalctl -u model-router -n 100`
2. Verify backend status: `systemctl status <service>`
3. Check VRAM: `nvidia-smi`
4. Test health: `curl http://localhost:8002/health`

---

**Maintained by:** Ivan  
**Environment:** Ubuntu 24.04, RTX 6000 Pro Blackwell, CUDA 12.9
