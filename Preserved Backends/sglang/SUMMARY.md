# SGLang Setup Complete! ✓

## Current Status
✅ **Server Running:** SGLang with Mistral-Large-Instruct-2411-AWQ  
✅ **Port:** 8001  
✅ **Tensor Parallel:** TP=4 (using GPUs 0-3)  
✅ **Quantization:** awq_marlin (optimized)  
✅ **Context Length:** 24,576 tokens  
✅ **Performance:** ~14-15 tok/s  

## Performance Summary

**Current Speed:** 14.37 tok/s (measured)  
**Expected Range:** 14-18 tok/s for TP=4 on PCIe GPUs  

### Why not faster?
- PCIe 3.0 bandwidth limits inter-GPU communication
- TP=4 requires significant cross-GPU data transfer
- awq_marlin quantization has some overhead with TP

### torch.compile Impact:
- **WITHOUT** (current): 14-18 tok/s, fast startup (45s)
- **WITH:** 17-22 tok/s, slow startup (15-20 mins first time)

## How to Monitor Tok/s

### Method 1: Test Script (Easiest)
```bash
/home/ivan/sglang/test_tokps.sh
```

### Method 2: Watch Logs
```bash
tail -f /home/ivan/sglang/sglang.log | grep -i "finish:"
```
Look for `e2e_latency` in the output, calculate: `completion_tokens / e2e_latency`

### Method 3: Metrics Endpoint
```bash
curl -s http://localhost:8001/metrics | grep throughput
```

### Method 4: In Open-WebUI
The UI shows tok/s at the bottom of each response automatically!

## Server Management

### Start Server
```bash
cd /home/ivan/sglang && nohup ./start_sglang_mistral_tp4.sh > sglang.log 2>&1 &
```

### Stop Server
```bash
pkill -f "sglang.launch_server"
```

### Check Status
```bash
curl -s http://localhost:8001/get_model_info | jq .
```

### View Logs
```bash
tail -f /home/ivan/sglang/sglang.log
```

### GPU Usage
```bash
nvidia-smi
```

## Open-WebUI Integration

### Add SGLang to Open-WebUI:
1. Go to Settings → Connections
2. Add new OpenAI API connection:
   - **URL:** `http://localhost:8001/v1`
   - **API Key:** (leave blank or use dummy key)
   - **Model:** `mistral-large-2411-awq`
3. Test connection and save

### Use in Chat:
- Select "mistral-large-2411-awq" model
- Chat normally - tok/s shows at bottom
- Response quality excellent with Mistral-Large

## Files Created

- `/home/ivan/sglang/start_sglang_mistral_tp4.sh` - Server startup script
- `/home/ivan/sglang/test_tokps.sh` - Performance testing script
- `/home/ivan/sglang/monitor_tokps.sh` - Interactive monitoring
- `/home/ivan/sglang/sglang.log` - Server logs
- `/home/ivan/sglang/MONITORING.md` - Detailed monitoring guide
- `/home/ivan/sglang/TORCH_COMPILE_INFO.md` - torch.compile explained
- `/home/ivan/sglang/SUMMARY.md` - This file

## Next Steps

### Option 1: Use as-is (Recommended)
- 14-15 tok/s is solid performance
- Test quality in Open-WebUI
- Compare with your TabbyAPI setup

### Option 2: Enable torch.compile for +20% speed
```bash
# Edit start script, add: --enable-torch-compile
# First startup takes 15-20 mins
# Subsequent startups ~90s
# Speed improves to ~17-22 tok/s
```

### Option 3: Try TP=2 for potentially better tok/s
```bash
# Edit start script, change: --tp 4 to --tp 2
# Uses only 2 GPUs but less cross-GPU overhead
# May get 16-20 tok/s
```

## Expected Tok/s by Configuration

| Config | Tok/s | Startup | GPUs Used |
|--------|-------|---------|-----------|
| TP=4, no compile | 14-18 | 45s | 4 |
| TP=4, compiled | 17-22 | 20m / 90s | 4 |
| TP=2, no compile | 16-20 | 40s | 2 |
| TP=2, compiled | 20-25 | 15m / 75s | 2 |

## Troubleshooting

### Server won't start
```bash
# Clean GPU memory
fuser -k /dev/nvidia*
sleep 3
# Restart
cd /home/ivan/sglang && nohup ./start_sglang_mistral_tp4.sh > sglang.log 2>&1 &
```

### Out of memory errors
- Reduce `--mem-fraction-static` to 0.75
- Reduce `--context-length` to 16384

### Slow performance
- Check GPU usage: `nvidia-smi`
- Ensure 4 GPUs show ~20GB usage each
- Try enabling torch.compile for production

## Contact/Support

For issues with SGLang specifically, check:
- GitHub: https://github.com/sgl-project/sglang
- Docs: https://sgl-project.github.io/

Your current setup is working well at 14-15 tok/s!
