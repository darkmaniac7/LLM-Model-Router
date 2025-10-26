# Blackwell GB200 Multi-Model LLM Setup - Complete Documentation

**System:** Ubuntu 22.04 LTS | **GPU:** NVIDIA GB200 (Blackwell) | **Date:** October 2025

## 📋 Table of Contents
1. [System Overview](#system-overview)
2. [Architecture](#architecture)
3. [Available Models](#available-models)
4. [Services & Auto-Start](#services--auto-start)
5. [Router Features](#router-features)
6. [Model Switching](#model-switching)
7. [Performance](#performance)
8. [Troubleshooting](#troubleshooting)
9. [File Locations](#file-locations)

---

## 🔍 System Overview

### What You Have
- **6 LLM models** available via single unified endpoint
- **Automatic model switching** - just select from OpenWebUI dropdown
- **Real-time performance metrics** - tok/s shown at end of every response
- **Two backends**: SGLang (for AWQ) + TabbyAPI (for EXL2)
- **Systemd services** - auto-start on boot, auto-restart on crash
- **Streaming status updates** - no timeout during 30-90s model loads

### Current Performance
All models running at **~22-25 tok/s** due to Blackwell sm_120 kernel limitations (Triton backend not fully optimized yet).

**Note:** This is ~50% slower than your previous 4x3090 setup (37 tok/s) due to software maturity, not hardware capability.

---

## 🏗️ Architecture

```
┌──────────────────┐
│   OpenWebUI      │  User selects model from dropdown
│   Port: 3000     │
└────────┬─────────┘
         │ HTTP Request
         ↓
┌──────────────────┐
│  Model Router    │  Detects model change
│   Port: 8002     │  • Stops other backend
│   v3.1.1         │  • Restarts correct backend
└────────┬─────────┘  • Streams loading status
         │            • Appends tok/s to response
         ↓
    ┌───┴────┐
    │        │
    ↓        ↓
┌─────┐  ┌──────┐
│SGLang│  │Tabby │  Inference Engines
│30000 │  │ 5000 │  • Load model weights
└──┬──┘  └───┬──┘  • Generate text
   │         │
   └────┬────┘
        ↓
   ┌─────────┐
   │ GB200   │  Single GPU
   │ 95GB    │  Blackwell sm_120
   └─────────┘
```

### Request Flow
1. User selects model in OpenWebUI
2. OpenWebUI sends chat request to router (port 8002)
3. Router detects if model needs to switch
4. If switching:
   - Stops current backend service
   - Updates systemd service config
   - Restarts appropriate backend
   - Streams "⏳ Loading... 10s/180s" updates
   - Shows "✅ Model ready! (45s)"
5. Router forwards request to backend
6. Backend generates response
7. Router appends "⚡ 25.6 tok/s" to end
8. User sees complete response with metrics

---

## 📦 Available Models

### SGLang Backend (AWQ Models - Port 30000)

| Model ID | Size | Description | Script |
|----------|------|-------------|--------|
| `mistral-large-2411-awq` | 123B | Mistral Large 2411 | `start_sglang_mistral_blackwell.sh` |
| `llama-3.3-70b-awq` | 70B | Llama 3.3 Instruct Abliterated | `start_sglang_llama33_blackwell.sh` |
| `deepseek-r1-distill-70b-awq` | 70B | DeepSeek R1 Distill | `start_sglang_deepseek_blackwell.sh` |
| `magnum-v4-123b-awq` | 123B | Magnum v4 | `start_sglang_magnum_blackwell.sh` |
| `kat-dev-awq-8bit` | 32B | KAT Dev (tool-calling) | `start_sglang_katdev_blackwell.sh` |

**All SGLang models configured with:**
- Single GPU (GPU 0)
- Triton attention backend
- 88% memory fraction
- Chunked prefill (8192)
- Port 30000

### TabbyAPI Backend (EXL2 Models - Port 5000)

| Model ID | Size | Description | Status |
|----------|------|-------------|--------|
| `monstral-123b-exl2-4bpw` | 123B | Monstral v2 (4-bit EXL2) | Downloading |

---

## ⚙️ Services & Auto-Start

### Systemd Services

All services configured to:
- ✅ Start automatically on boot
- ✅ Restart automatically on failure
- ✅ Log to systemd journal

#### 1. SGLang Service
**File:** `/etc/systemd/system/sglang.service`
**Status:** Active (running mistral-large by default)

```bash
# Check status
systemctl status sglang.service

# View logs
journalctl -u sglang.service -f

# Restart manually
systemctl restart sglang.service
```

#### 2. TabbyAPI Service
**File:** `/etc/systemd/system/tabbyapi.service`
**Status:** Stopped (starts when EXL2 model selected)

```bash
# Check status
systemctl status tabbyapi.service

# View logs
journalctl -u tabbyapi.service -f
```

#### 3. Router Service (Not Yet Configured)
Currently running manually. To make persistent:

```bash
# Create service file
sudo tee /etc/systemd/system/llm-router.service > /dev/null << 'SERVICE'
[Unit]
Description=Blackwell Multi-Model Router
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/ivan/sglang
ExecStart=/home/ivan/sglang/sglang-env/bin/python /home/ivan/sglang/model_router_blackwell.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable llm-router.service
sudo systemctl start llm-router.service
```

### Boot Sequence
1. System boots
2. Network starts
3. `sglang.service` starts (loads last-used model)
4. `llm-router.service` starts (if configured)
5. OpenWebUI accessible immediately
6. Model ready in ~45-60 seconds

---

## 🔀 Router Features

### Version 3.1.1 Capabilities

#### 1. Streaming Status Updates
Prevents timeout during model loading:
```
🔄 Switching to llama-3.3-70b-awq...

⏳ Loading model... 10s / 180s
⏳ Loading model... 20s / 180s
⏳ Loading model... 30s / 180s

✅ Model ready! (33s)

[Response follows]
```

#### 2. Inline Performance Metrics
Appended to end of every response:
```
The capital of France is Paris!

---
⚡ 25.6 tok/s (~128 tokens in 5.0s)
```

Works for both streaming and non-streaming requests.

#### 3. Automatic Backend Switching
Router handles everything:
- Stops TabbyAPI when switching to SGLang model
- Stops SGLang when switching to TabbyAPI model
- Updates systemd service configuration
- Waits for backend to be ready
- Forwards request seamlessly

#### 4. Error Handling
- Shows clear error messages in chat
- Logs detailed errors for debugging
- Gracefully handles timeouts
- Prevents partial/broken responses

### Router Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/v1/models` | GET | List available models |
| `/v1/chat/completions` | POST | Chat with model (auto-switch) |
| `/health` | GET | Check router + backend status |

---

## 🔄 Model Switching

### Method 1: OpenWebUI (Recommended)
1. Click model dropdown at top of chat
2. Select any of the 6 models
3. Send a message
4. Watch loading status in chat
5. Response appears with tok/s metric

**Switch time:** 30-60 seconds depending on model size

### Method 2: Direct API
```bash
curl -X POST http://localhost:8002/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "kat-dev-awq-8bit",
    "messages": [{"role": "user", "content": "Hello"}],
    "stream": true
  }'
```

### Method 3: Check Current Model
```bash
curl -s http://localhost:8002/health | jq '.current_model'
```

---

## 📊 Performance

### Current Metrics
- **All models:** ~22-25 tok/s
- **Power draw:** ~500W during inference
- **GPU utilization:** 100% SM, 91% memory
- **Model load time:** 30-60 seconds
- **Switch time:** 45-90 seconds

### Why Lower Than Expected?

**Blackwell sm_120 Kernel Maturity Issue:**
- Triton backend works but not optimized for sm_120
- FA4 doesn't support sm_120 yet (9.x/10.x only)
- GPU capable of 600W TDP but kernels only use ~500W
- Compute-bound by kernel efficiency, not hardware

**Comparison:**
- Previous 4x3090 setup: 37 tok/s
- Current GB200: 22-25 tok/s
- Expected after optimization: 60-80+ tok/s

### Tracking Improvements
Monitor these for sm_120 support:
- [SGLang GitHub Issues](https://github.com/sgl-project/sglang/issues) - Blackwell support
- [FlashInfer](https://github.com/flashinfer-ai/flashinfer) - sm_120 kernels
- PyTorch CUDA 12.8+ releases

---

## 🔧 Troubleshooting

### Router Not Responding
```bash
# Check if running
ps aux | grep model_router_blackwell

# View logs
tail -f /tmp/router_blackwell.log

# Restart
pkill -f model_router_blackwell
nohup /home/ivan/sglang/sglang-env/bin/python \
  /home/ivan/sglang/model_router_blackwell.py \
  > /tmp/router_blackwell.log 2>&1 &
```

### Model Won't Load
```bash
# Check backend service
systemctl status sglang.service
systemctl status tabbyapi.service

# View recent logs
journalctl -u sglang.service -n 100 --no-pager

# Restart backend
systemctl restart sglang.service
```

### "Model Loading Timed Out"
- Check if GPU has enough memory: `nvidia-smi`
- Increase timeout in router (currently 180s)
- Check service logs for actual error

### OpenWebUI Shows Old Model
```bash
# Restart router
pkill -f model_router
nohup /home/ivan/sglang/sglang-env/bin/python \
  /home/ivan/sglang/model_router_blackwell.py \
  > /tmp/router_blackwell.log 2>&1 &

# Clear browser cache
# Refresh OpenWebUI
```

### Low Performance
This is expected (see Performance section). To verify:
```bash
# Check GPU is being used
nvidia-smi

# Should show:
# - 100% GPU utilization during generation
# - ~500W power draw
# - 88GB VRAM used
```

---

## 📁 File Locations

### Configuration
```
/etc/systemd/system/sglang.service       # SGLang service
/etc/systemd/system/tabbyapi.service     # TabbyAPI service
/home/ivan/tabbyAPI/config.yml           # TabbyAPI config
```

### Scripts
```
/home/ivan/sglang/
├── model_router_blackwell.py            # Main router (v3.1.1)
├── start_sglang_mistral_blackwell.sh    # Mistral startup
├── start_sglang_llama33_blackwell.sh    # Llama startup
├── start_sglang_deepseek_blackwell.sh   # DeepSeek startup
├── start_sglang_magnum_blackwell.sh     # Magnum startup
└── start_sglang_katdev_blackwell.sh     # KAT-Dev startup
```

### Models
```
/home/ivan/models/
├── Mistral-Large-Instruct-2411-AWQ/
├── llama3.3-70B-instruct-abliterated-awq/
├── DeepSeek-R1-Distill-Llama-70B-AWQ/
├── Magnum-v4-123B-AWQ/
├── KAT-Dev-AWQ-8bit/
└── Monstral-123B-v2-exl2-4.0bpw/        # Downloading
```

### Logs
```
/tmp/router_blackwell.log                # Router logs
journalctl -u sglang.service             # SGLang logs
journalctl -u tabbyapi.service           # TabbyAPI logs
```

### Documentation
```
/home/ivan/llm_docs/
├── BLACKWELL_SETUP_COMPLETE.md          # This file
├── BLACKWELL_IMPROVEMENTS.md            # Performance notes
└── QUICK_REFERENCE.md                   # Common commands
```

---

## 🚀 Quick Reference

### Daily Operations
```bash
# Check everything is running
curl http://localhost:8002/health | jq .

# List available models
curl http://localhost:8002/v1/models | jq '.data[].id'

# View current model
curl http://localhost:8002/health | jq '.current_model'

# Monitor GPU
watch -n 1 nvidia-smi

# Check service status
systemctl status sglang.service
```

### Restart Everything
```bash
# Restart backends
systemctl restart sglang.service
systemctl restart tabbyapi.service

# Restart router
pkill -f model_router
nohup /home/ivan/sglang/sglang-env/bin/python \
  /home/ivan/sglang/model_router_blackwell.py \
  > /tmp/router_blackwell.log 2>&1 &

# Wait 60 seconds for model to load
sleep 60

# Test
curl http://localhost:8002/health
```

### View Logs in Real-Time
```bash
# Router
tail -f /tmp/router_blackwell.log

# SGLang
journalctl -u sglang.service -f

# TabbyAPI
journalctl -u tabbyapi.service -f
```

---

## 📝 Version History

- **v3.1.1** (Oct 2025) - Blackwell single-GPU setup
  - Multi-backend router (SGLang + TabbyAPI)
  - Streaming status updates
  - Inline tok/s metrics
  - Fixed error handling
  - 6 models available

- **v3.0** (Oct 2025) - 4x3090 multi-GPU setup
  - SGLang only
  - 5 models
  - Torch.compile
  - NVLink optimization

---

**Maintained by:** Ivan  
**Last Updated:** October 25, 2025  
**Hardware:** NVIDIA GB200 Blackwell (95GB VRAM)  
**Software:** SGLang 0.5.4, TabbyAPI, Ubuntu 22.04
