# Blackwell LLM Setup - Quick Reference

## 🎯 Most Common Commands

### Check Status
```bash
# Everything healthy?
curl http://localhost:8002/health | jq .

# Which model is loaded?
curl http://localhost:8002/health | jq '.current_model'

# List all models
curl http://localhost:8002/v1/models | jq '.data[].id'

# GPU usage
nvidia-smi
```

### Restart Services
```bash
# Restart router
pkill -f model_router && \
nohup /home/ivan/sglang/sglang-env/bin/python \
  /home/ivan/sglang/model_router_blackwell.py \
  > /tmp/router_blackwell.log 2>&1 &

# Restart SGLang
systemctl restart sglang.service

# Restart TabbyAPI
systemctl restart tabbyapi.service
```

### View Logs
```bash
# Router logs (live)
tail -f /tmp/router_blackwell.log

# SGLang logs (live)
journalctl -u sglang.service -f

# Last 100 lines of SGLang
journalctl -u sglang.service -n 100 --no-pager
```

### Test Response
```bash
# Quick test with Mistral
curl -X POST http://localhost:8002/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral-large-2411-awq",
    "messages": [{"role": "user", "content": "Say hello"}],
    "max_tokens": 20,
    "stream": false
  }' | jq -r '.choices[0].message.content'
```

## 📋 Available Models

```
mistral-large-2411-awq       # 123B, Mistral Large
llama-3.3-70b-awq            # 70B, Llama 3.3 Abliterated
deepseek-r1-distill-70b-awq  # 70B, DeepSeek R1
magnum-v4-123b-awq           # 123B, Magnum v4
kat-dev-awq-8bit             # 32B, Tool calling
monstral-123b-exl2-4bpw      # 123B, EXL2 (downloading)
```

## 🔧 Troubleshooting One-Liners

```bash
# Is router running?
ps aux | grep model_router_blackwell | grep -v grep

# Is SGLang running?
systemctl is-active sglang.service

# Check GPU memory
nvidia-smi --query-gpu=memory.used,memory.total --format=csv

# Kill everything and restart
pkill -f model_router; systemctl restart sglang.service; \
sleep 3; nohup /home/ivan/sglang/sglang-env/bin/python \
/home/ivan/sglang/model_router_blackwell.py > /tmp/router_blackwell.log 2>&1 &

# Watch GPU in real-time
watch -n 1 nvidia-smi
```

## 📊 Performance Check

```bash
# Current tok/s (from logs)
journalctl -u sglang.service -n 50 | grep "tok/s"

# Power draw
nvidia-smi --query-gpu=power.draw --format=csv,noheader

# GPU utilization
nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader
```

## 🚀 OpenWebUI Access

- **URL:** http://localhost:3000
- **Router:** http://localhost:8002
- **Models:** Select from dropdown, wait 30-60s for switch

## 📁 Key Files

```
/home/ivan/sglang/model_router_blackwell.py
/home/ivan/sglang/start_sglang_*_blackwell.sh
/etc/systemd/system/sglang.service
/etc/systemd/system/tabbyapi.service
/tmp/router_blackwell.log
```

## 💡 Tips

- Model switch takes 30-60 seconds
- All responses show tok/s at bottom
- Router shows loading progress in chat
- Current performance: ~22-25 tok/s (kernel limitation)
- GPU should show 100% utilization during generation
