# SGLang Multi-Model Setup - Complete Documentation

## 📚 Table of Contents
1. [System Overview](#system-overview)
2. [Architecture](#architecture)
3. [Directory Structure](#directory-structure)
4. [Model Startup Scripts](#model-startup-scripts)
5. [Model Router](#model-router)
6. [Systemd Services](#systemd-services)
7. [How to Switch Models](#how-to-switch-models)
8. [Troubleshooting](#troubleshooting)
9. [Performance Monitoring](#performance-monitoring)
10. [Adding New Models](#adding-new-models)

---

## 🔍 System Overview

This system runs multiple large language models (LLMs) using **SGLang** as the inference backend, with an automatic model-switching router that integrates seamlessly with **OpenWebUI**.

### Key Features:
- ✅ **Automatic model switching** - Select any model from OpenWebUI dropdown
- ✅ **Streaming status updates** - No timeout during model loading
- ✅ **Torch.compile optimization** - 15-20% faster inference
- ✅ **CUDA graphs** - Enabled by default for maximum throughput
- ✅ **NVLink support** - Multi-GPU communication for faster inference
- ✅ **Systemd management** - Auto-restart on failure, boot on startup
- ✅ **Unified port** - All models serve on port 8001, router on 8002

### Current Performance:
- **Mistral-Large AWQ (70B)**: ~40-45 tok/s @ 350W
- **KAT-Dev AWQ-8bit (32B)**: ~58-63 tok/s @ 300W  
- **DeepSeek-R1-Distill AWQ (70B)**: ~53 tok/s @ 300W
- **Llama 3.3 AWQ (70B)**: ~40-45 tok/s
- **Magnum-v4 AWQ (123B)**: ~19 tok/s @ 250W

---

## 🏗️ Architecture

```
┌─────────────────┐
│   OpenWebUI     │  (User Interface)
│   Port: 3000    │
└────────┬────────┘
         │ HTTP Requests
         ↓
┌─────────────────┐
│  Model Router   │  (Python FastAPI)
│   Port: 8002    │  - Detects model change
└────────┬────────┘  - Switches backend
         │            - Streams loading status
         ↓
┌─────────────────┐
│ Systemd Service │  (Process Manager)
│  sglang.service │  - Restarts on failure
└────────┬────────┘  - Manages one model at a time
         │
         ↓
┌─────────────────┐
│  SGLang Server  │  (Inference Engine)
│   Port: 8001    │  - Loads model weights
└─────────────────┘  - Serves completions
         │
         ↓
┌─────────────────┐
│   GPUs 1-4      │  (Hardware)
│  RTX 3090 x4    │  - NVLink connected
└─────────────────┘  - Tensor parallelism
```

### Request Flow:
1. **User** selects a model in OpenWebUI
2. **OpenWebUI** sends chat request to router (port 8002)
3. **Router** detects model name in request
4. **Router** checks if current model matches requested model
5. If different:
   - Router updates systemd service config
   - Router restarts sglang.service
   - Router streams "Loading..." messages every 10s
   - Router waits for model to be ready (checks /get_model_info)
6. **Router** forwards request to SGLang (port 8001)
7. **SGLang** generates response and streams back
8. **Router** streams response to OpenWebUI
9. **User** sees the response

---

## 📁 Directory Structure

```
/home/ivan/sglang/
├── model_router_v3.py              # Main router application
├── switch_model.sh                 # CLI tool to switch models
├── start_sglang_mistral_tp4_compiled.sh
├── start_sglang_katdev.sh
├── start_sglang_deepseek_tp4_compiled.sh
├── start_sglang_llama33_tp4_compiled.sh
├── start_sglang_glm_tp4_compiled.sh
├── start_sglang_magnum.sh
├── monitor_compile.sh              # Monitor torch.compile progress
├── monitor_tokps.sh                # Real-time tok/s monitoring
├── test_tokps.sh                   # Benchmark script
├── sglang-env/                     # Python virtual environment
│   └── bin/
│       ├── python
│       └── activate
└── IMPROVEMENTS_V3.md              # This file!

/home/ivan/models/
├── Mistral-Large-Instruct-2411-AWQ/
├── KAT-Dev-AWQ-8bit/
├── Llama-3.3-70B-Instruct-Abliterated-AWQ/
├── deepseek-r1-distill-llama-70b-AWQ/
├── GLM-4.5-Air-AWQ/
└── Magnum-v4-123B-AWQ/

/etc/systemd/system/
├── sglang.service                  # Main SGLang service
└── model-router.service            # Router service
```

---

## 🚀 Model Startup Scripts

Each model has a dedicated startup script that configures SGLang with optimal parameters.

### Script Template Structure:

```bash
#!/bin/bash
# Model name and description

source /home/ivan/sglang/sglang-env/bin/activate

# GPU selection (NVLink connected GPUs for best performance)
export CUDA_VISIBLE_DEVICES=1,2,3,4

# Launch SGLang server
/home/ivan/sglang/sglang-env/bin/python -m sglang.launch_server \
    --model-path /home/ivan/models/MODEL_NAME \
    --host 0.0.0.0 \
    --port 8001 \
    --tp 4 \                         # Tensor parallelism (4 GPUs)
    --context-length 24576 \          # Max context window
    --quantization awq_marlin \       # Quantization method
    --served-model-name MODEL_ID \    # Name for API
    --mem-fraction-static 0.80 \      # GPU VRAM usage (80%)
    --log-level info \
    --log-requests \
    --enable-torch-compile \          # 15-20% speed boost
    --sleep-on-idle                   # Reduce CPU usage when idle
```

### Key Parameters Explained:

| Parameter | Purpose | Notes |
|-----------|---------|-------|
| `--model-path` | Location of model files | Must be full path |
| `--port` | Port to serve on | Always 8001 for unified routing |
| `--tp` | Tensor parallelism size | Must divide attention heads evenly |
| `--context-length` | Max sequence length | Limited by VRAM |
| `--quantization` | Quant format | `awq_marlin`, `gptq_marlin`, etc. |
| `--served-model-name` | API model identifier | Used by router to detect model |
| `--mem-fraction-static` | GPU memory allocation | 0.80 = 80% of VRAM |
| `--enable-torch-compile` | JIT compilation | Adds 5-15min startup, 15-20% speed |
| `--sleep-on-idle` | Reduce CPU polling | Prevents 100% CPU when idle |

### Example: Mistral-Large

```bash
#!/bin/bash
source /home/ivan/sglang/sglang-env/bin/activate
export CUDA_VISIBLE_DEVICES=1,2,3,4

/home/ivan/sglang/sglang-env/bin/python -m sglang.launch_server \
    --model-path /home/ivan/models/Mistral-Large-Instruct-2411-AWQ \
    --host 0.0.0.0 \
    --port 8001 \
    --tp 4 \
    --context-length 24576 \
    --quantization awq_marlin \
    --served-model-name mistral-large-2411-awq \
    --mem-fraction-static 0.80 \
    --log-level info \
    --log-requests \
    --enable-torch-compile \
    --sleep-on-idle
```

**When to use torch.compile:**
- ✅ Production use (models rarely change)
- ✅ Long-running sessions
- ❌ Development/testing (frequent model switches)
- ❌ Quick tests

---

## 🔀 Model Router

The router (`model_router_v3.py`) is a FastAPI application that:
1. **Lists available models** via `/v1/models` endpoint
2. **Handles chat requests** via `/v1/chat/completions` endpoint
3. **Detects model switches** by comparing request model name
4. **Updates systemd config** to change the startup script
5. **Restarts sglang.service** to load new model
6. **Streams loading status** every 10 seconds (prevents timeout)
7. **Proxies requests** to SGLang backend once ready

### Key Features:

#### 1. Streaming Status Updates
Prevents OpenWebUI timeout during 5-15 minute model loads:
```
🔄 Switching to kat-dev-awq-8bit...
⏳ Loading model... 10s / 300s
⏳ Loading model... 20s / 300s
⏳ Loading model... 30s / 300s
✅ Model ready!
```

#### 2. Delta Streaming Fix
SGLang sends **cumulative** tokens, router converts to **delta** tokens:
```python
# Track last position to avoid repeated text
last_content_length = 0

# Extract only NEW content since last chunk
new_content = full_content[last_content_length:]
last_content_length = len(full_content)

# Send only the delta
yield {"delta": {"content": new_content}}
```

#### 3. Model Detection
```python
MODELS = {
    "mistral-large-2411-awq": "/home/ivan/sglang/start_sglang_mistral_tp4_compiled.sh",
    "llama-3.3-70b-awq": "/home/ivan/sglang/start_sglang_llama33_tp4_compiled.sh",
    "deepseek-r1-distill-70b-awq": "/home/ivan/sglang/start_sglang_deepseek_tp4_compiled.sh",
    "kat-dev-awq-8bit": "/home/ivan/sglang/start_sglang_katdev.sh",
    "magnum-v4-123b-awq": "/home/ivan/sglang/start_sglang_magnum.sh",
}
```

#### 4. Health Checking
```python
async def wait_for_sglang_ready():
    while time.time() - start < timeout:
        try:
            response = await client.get(f"{SGLANG_URL}/get_model_info")
            if response.status_code == 200:
                return True  # Model ready!
        except:
            pass
        await asyncio.sleep(5)
    return False  # Timeout
```

### Router Endpoints:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/v1/models` | GET | List available models |
| `/v1/chat/completions` | POST | Chat with current model |
| `/health` | GET | Check router + backend status |

---

## ⚙️ Systemd Services

### sglang.service
Manages the SGLang inference server.

**Location:** `/etc/systemd/system/sglang.service`

```ini
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
```

**Key Points:**
- `ExecStart` is updated by router when switching models
- `Restart=always` ensures auto-recovery from crashes
- `RestartSec=10` waits 10s before restart attempt
- Logs go to systemd journal (view with `journalctl`)

### model-router.service
Manages the router application.

**Location:** `/etc/systemd/system/model-router.service`

```ini
[Unit]
Description=SGLang Model Router v3.0
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/ivan/sglang
Environment="PATH=/home/ivan/sglang/sglang-env/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/home/ivan/sglang/sglang-env/bin/python /home/ivan/sglang/model_router_v3.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Key Points:**
- Runs on port 8002
- Python virtual environment in PATH
- Auto-restarts on failure
- Independent from SGLang service

---

## 🔄 How to Switch Models

### Method 1: OpenWebUI (Recommended)
1. Open OpenWebUI (http://localhost:3000)
2. Click model dropdown at top
3. Select desired model
4. Wait for loading message
5. Start chatting!

**What happens:**
- OpenWebUI sends request with new model name
- Router detects change
- Router restarts sglang.service
- Router streams "Loading..." updates
- Once ready, chat proceeds normally

### Method 2: CLI Script
```bash
cd /home/ivan/sglang
./switch_model.sh mistral

# Available models:
#   mistral  - Mistral-Large-Instruct-2411-AWQ
#   llama33  - Llama 3.3 70B Instruct
#   deepseek - DeepSeek-R1-Distill-Llama-70B
#   glm      - GLM-4.5-Air-AWQ
#   magnum   - Magnum-v4-123B
```

**What it does:**
```bash
# 1. Update systemd service
sudo sed -i "s|ExecStart=.*|ExecStart=/home/ivan/sglang/$SCRIPT|" /etc/systemd/system/sglang.service

# 2. Reload systemd
sudo systemctl daemon-reload

# 3. Restart service
sudo systemctl restart sglang.service
```

### Method 3: Manual (For Debugging)
```bash
# Stop current model
sudo systemctl stop sglang.service

# Edit service file
sudo nano /etc/systemd/system/sglang.service
# Change ExecStart= line to desired script

# Reload and start
sudo systemctl daemon-reload
sudo systemctl start sglang.service

# Monitor startup
sudo journalctl -u sglang.service -f
```

---

## 🔧 Troubleshooting

### Model won't load / Service fails to start

**Check service status:**
```bash
sudo systemctl status sglang.service
```

**View recent logs:**
```bash
sudo journalctl -u sglang.service -n 100 --no-pager
```

**Follow live logs:**
```bash
sudo journalctl -u sglang.service -f
```

**Common issues:**

| Error | Cause | Solution |
|-------|-------|----------|
| `CUDA out of memory` | Model too large for VRAM | Lower `--mem-fraction-static` or reduce `--tp` |
| `Port 8001 already in use` | Old process still running | `sudo pkill -9 python` then restart |
| `Invalid device id` | GPU not available | Check `nvidia-smi`, adjust `CUDA_VISIBLE_DEVICES` |
| `Attention heads not divisible` | TP size incompatible | Use TP=1, 2, or 4 depending on model |
| `Service timeout` | torch.compile taking too long | Wait 5-15 min OR disable torch.compile |

### Router not working

**Check router status:**
```bash
sudo systemctl status model-router.service
```

**View router logs:**
```bash
sudo journalctl -u model-router.service -f
```

**Test router manually:**
```bash
curl http://localhost:8002/v1/models
curl http://localhost:8002/health
```

### OpenWebUI shows old model

**Cause:** Router cached state

**Solution:**
```bash
# Restart router
sudo systemctl restart model-router.service

# Restart OpenWebUI
sudo systemctl restart open-webui.service  # or docker restart open-webui
```

### Model loads but slow performance

**Check GPU power limits:**
```bash
nvidia-smi --query-gpu=index,power.limit,power.draw --format=csv
```

**Increase power (if safe):**
```bash
# Set all GPUs to 300W
for gpu in 0 1 2 3 4 5; do sudo nvidia-smi -i $gpu -pl 300; done

# Or 350W (requires good PSU and cooling)
for gpu in 0 1 2 3 4 5; do sudo nvidia-smi -i $gpu -pl 350; done
```

**Check NVLink status:**
```bash
nvidia-smi nvlink --status
```

### Service keeps restarting

**Disable auto-restart temporarily:**
```bash
sudo systemctl stop sglang.service
```

**Run manually to see full errors:**
```bash
cd /home/ivan/sglang
./start_sglang_mistral_tp4_compiled.sh
```

---

## 📊 Performance Monitoring

### Real-time tok/s Monitoring

**During generation:**
```bash
cd /home/ivan/sglang
./monitor_tokps.sh
```

Output:
```
[2025-10-14 11:23:45] Tokens: 124, Speed: 42.3 tok/s
[2025-10-14 11:23:46] Tokens: 167, Speed: 43.0 tok/s
```

### Torch.compile Progress

**Monitor compilation (first startup only):**
```bash
cd /home/ivan/sglang
./monitor_compile.sh
```

Output:
```
[2025-10-14 11:20:12] Compiling prefill batch_size=1...
[2025-10-14 11:20:45] Compiling decode batch_size=1...
[2025-10-14 11:21:30] Autotuning CUDA graphs...
```

### Benchmark Script

**Test 1000 tokens:**
```bash
cd /home/ivan/sglang
./test_tokps.sh
```

Generates long response and calculates average tok/s.

### GPU Monitoring

**Watch GPU usage:**
```bash
watch -n 1 nvidia-smi
```

**Detailed power/memory:**
```bash
nvidia-smi --query-gpu=index,name,power.draw,power.limit,memory.used,memory.total,utilization.gpu --format=csv
```

### Service Health

**Quick status check:**
```bash
# SGLang status
sudo systemctl is-active sglang.service

# Router status  
sudo systemctl is-active model-router.service

# Test endpoints
curl -s http://localhost:8001/get_model_info | jq .
curl -s http://localhost:8002/health | jq .
```

---

## ➕ Adding New Models

### Step 1: Download Model
```bash
cd /home/ivan/models

# Option A: HuggingFace CLI (faster, parallel downloads)
huggingface-cli download \
    REPO/MODEL_NAME \
    --local-dir ./MODEL_NAME \
    --local-dir-use-symlinks False

# Option B: Git LFS
git clone https://huggingface.co/REPO/MODEL_NAME
```

### Step 2: Create Startup Script
```bash
cd /home/ivan/sglang
nano start_sglang_MODELNAME.sh
```

**Script template:**
```bash
#!/bin/bash
# MODEL_NAME - Brief description

source /home/ivan/sglang/sglang-env/bin/activate

export CUDA_VISIBLE_DEVICES=1,2,3,4

/home/ivan/sglang/sglang-env/bin/python -m sglang.launch_server \
    --model-path /home/ivan/models/MODEL_NAME \
    --host 0.0.0.0 \
    --port 8001 \
    --tp 4 \
    --context-length 24576 \
    --quantization awq_marlin \
    --served-model-name model-name-id \
    --mem-fraction-static 0.80 \
    --log-level info \
    --log-requests \
    --enable-torch-compile \
    --sleep-on-idle
```

**Make executable:**
```bash
chmod +x start_sglang_MODELNAME.sh
```

### Step 3: Add to Router
```bash
nano /home/ivan/sglang/model_router_v3.py
```

Add to `MODELS` dict:
```python
MODELS = {
    # ... existing models ...
    "model-name-id": "/home/ivan/sglang/start_sglang_MODELNAME.sh",
}
```

### Step 4: Add to CLI Switcher
```bash
nano /home/ivan/sglang/switch_model.sh
```

Add case:
```bash
case $MODEL in
    # ... existing cases ...
    modelname)
        SCRIPT="start_sglang_MODELNAME.sh"
        ;;
esac
```

### Step 5: Restart Router
```bash
sudo systemctl restart model-router.service
```

### Step 6: Test
```bash
# Via CLI
./switch_model.sh modelname

# Via OpenWebUI
# Select "model-name-id" from dropdown
```

---

## 🎯 Best Practices

### GPU Power Management
- Start at 250W, increase gradually
- Monitor temperatures and PSU load
- Use `nvidia-smi dmon` to watch real-time power draw
- Consider UPS capacity

### Model Selection
- **70B models**: Best balance of quality and speed (~40-60 tok/s)
- **123B models**: Slower but higher quality (~19 tok/s)
- **32B models**: Fastest, good for tool calling (~58-63 tok/s)

### Context Length
- Longer context = more VRAM usage
- Most use cases: 16K-32K is sufficient
- Reduce if CUDA OOM errors occur

### Torch.compile
- Enable for production (15-20% faster)
- Disable during development (faster restarts)
- First startup: 5-15 minutes
- Subsequent startups: instant (cached)

### NVLink
- Use GPUs 1-4 which have NVLink bridges
- 10-15% performance improvement
- Check status: `nvidia-smi nvlink --status`

### Systemd Management
- `systemctl status` - Check service health
- `systemctl restart` - Force restart
- `systemctl stop` - Stop before manual debugging
- `journalctl -f` - Follow logs in real-time

---

## 📞 Quick Reference

### Service Management
```bash
# Start/stop/restart
sudo systemctl start sglang.service
sudo systemctl stop sglang.service
sudo systemctl restart sglang.service

# Enable/disable autostart
sudo systemctl enable sglang.service
sudo systemctl disable sglang.service

# View status
sudo systemctl status sglang.service

# View logs
sudo journalctl -u sglang.service -f
```

### Model Switching
```bash
# CLI method
./switch_model.sh mistral

# Manual method
sudo systemctl stop sglang.service
sudo nano /etc/systemd/system/sglang.service  # Edit ExecStart
sudo systemctl daemon-reload
sudo systemctl start sglang.service
```

### GPU Management
```bash
# Set power limit (all GPUs)
for gpu in {0..5}; do sudo nvidia-smi -i $gpu -pl 300; done

# Check status
nvidia-smi

# NVLink status
nvidia-smi nvlink --status
```

### Testing
```bash
# Test SGLang directly
curl http://localhost:8001/get_model_info

# Test router
curl http://localhost:8002/health
curl http://localhost:8002/v1/models

# Benchmark
./test_tokps.sh
```

---

## 📝 Notes

### Version History
- **v1.0** - Initial TabbyAPI setup
- **v2.0** - SGLang migration, basic router
- **v3.0** - Streaming status, torch.compile, NVLink
- **v3.0.1** - Delta streaming fix, improved error handling

### Known Issues
1. GLM models have quantization compatibility issues
2. Pipeline parallelism (PP) not fully stable yet
3. First model load with torch.compile takes 5-15 minutes
4. Router shows "already active" during torch.compile phase

### Future Improvements
- [ ] Support for pipeline parallelism (TP+PP)
- [ ] Per-model temperature/sampler presets
- [ ] Automatic GPU power scaling based on load
- [ ] Model preloading/warm cache
- [ ] Multi-model concurrent serving

---

**Last Updated:** October 14, 2025  
**System:** Ubuntu 22.04 LTS, 6x RTX 3090, SGLang 0.5.3.post1  
**Maintainer:** Ivan

---

## 🙋 Getting Help

If stuck, check in this order:

1. **Logs first:**
   ```bash
   sudo journalctl -u sglang.service -n 100 --no-pager
   ```

2. **Service status:**
   ```bash
   sudo systemctl status sglang.service
   ```

3. **GPU health:**
   ```bash
   nvidia-smi
   ```

4. **Manual test:**
   ```bash
   sudo systemctl stop sglang.service
   cd /home/ivan/sglang
   ./start_sglang_mistral_tp4_compiled.sh
   # Watch for errors
   ```

5. **Restart everything:**
   ```bash
   sudo systemctl restart sglang.service
   sudo systemctl restart model-router.service
   ```

