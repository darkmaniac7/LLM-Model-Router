# Blackwell GB200 Multi-Model Setup

## ✅ Setup Complete

### Router
- **Port**: 8002
- **Router Script**: `/home/ivan/sglang/model_router_blackwell.py`
- **Type**: Multi-backend (SGLang + TabbyAPI)
- **Status**: Running with 6 models

### Available Models

#### SGLang Backend (AWQ models on port 30000)
1. **mistral-large-2411-awq** - Mistral Large 2411 123B
2. **llama-3.3-70b-awq** - Llama 3.3 70B Instruct Abliterated
3. **deepseek-r1-distill-70b-awq** - DeepSeek R1 Distill 70B
4. **magnum-v4-123b-awq** - Magnum v4 123B
5. **kat-dev-awq-8bit** - KAT Dev 32B (tool-calling/agentic)

#### TabbyAPI Backend (EXL2 models on port 5000)
6. **monstral-123b-exl2-4bpw** - Monstral 123B v2 (downloading: ~10GB/60GB)

## How It Works

The router automatically:
1. Lists all 6 models to OpenWebUI
2. When you select a model:
   - Stops the other backend if needed
   - Updates systemd service to point to the correct script
   - Restarts the appropriate backend
   - Waits for model to load (up to 3 minutes)
   - Forwards your request

Model switches take ~45-90 seconds depending on model size.

## OpenWebUI Configuration

Point OpenWebUI to: `http://localhost:8002`

All 6 models will appear in the dropdown. Select any model and the router handles everything.

## Testing

```bash
# Check available models
curl http://localhost:8002/v1/models | jq -r '.data[].id'

# Test any model
curl -X POST http://localhost:8002/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama-3.3-70b-awq",
    "messages": [{"role": "user", "content": "Hi"}],
    "max_tokens": 50
  }'

# Watch router logs during switch
tail -f /tmp/router_blackwell.log

# Check backend logs
journalctl -u sglang.service -f
journalctl -u tabbyapi.service -f
```

## Services

```bash
# Check which backend is running
systemctl status sglang.service
systemctl status tabbyapi.service

# Manual control (not recommended - let router handle it)
systemctl stop sglang.service
systemctl start tabbyapi.service
```

## Performance

All models running at **~22-25 tok/s** due to Blackwell sm_120 kernel limitations:
- Triton backend works but not optimized
- FA4 doesn't support sm_120 yet
- Power: ~500W vs 600W TDP (compute-bound)

**Note**: This is 50% slower than your old 4x3090 setup (37 tok/s).

### Tracking Updates
Monitor for sm_120 optimization:
- FlashInfer Blackwell support
- SGLang sm_120 kernels
- PyTorch CUDA 12.8+ updates

## Model Files

Blackwell-compatible startup scripts:
- `/home/ivan/sglang/start_sglang_mistral_blackwell.sh`
- `/home/ivan/sglang/start_sglang_llama33_blackwell.sh`
- `/home/ivan/sglang/start_sglang_deepseek_blackwell.sh`
- `/home/ivan/sglang/start_sglang_magnum_blackwell.sh`
- `/home/ivan/sglang/start_sglang_katdev_blackwell.sh`

All configured for:
- Single GPU (GPU 0)
- Port 30000
- Triton attention backend
- 88% memory fraction
- Chunked prefill (8192)

## Monstral Download Status

Check progress:
```bash
du -sh /home/ivan/models/Monstral-123B-v2-exl2-4.0bpw/
ps aux | grep huggingface
```

Once complete (~60GB total), the model will be automatically available via the router.

## Router Control

Start/stop router:
```bash
# Stop
pkill -f model_router_blackwell.py

# Start
nohup /home/ivan/sglang/sglang-env/bin/python /home/ivan/sglang/model_router_blackwell.py > /tmp/router_blackwell.log 2>&1 &

# Check
curl http://localhost:8002/health | jq .
```
