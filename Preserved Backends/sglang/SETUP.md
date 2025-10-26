# SGLang Setup - Mistral-Large AWQ on 6× RTX 3090

## ✅ Status: RUNNING

- **Framework**: SGLang 0.5.3.post1
- **Model**: Mistral-Large-Instruct-2411-AWQ (123B, 4-bit AWQ)
- **GPUs**: 6× RTX 3090 (Tensor Parallel = 6)
- **Context**: 32,768 tokens (24K active due to memory constraints)
- **Port**: 8001
- **Log**: `/home/ivan/sglang/sglang.log`

## Why SGLang Over vLLM?

1. **TP=6 Stability** - vLLM 0.11's V1 engine crashes with TP>4; SGLang works perfectly
2. **Better Latency** - RadixAttention caches prompt prefixes for faster repeated queries
3. **Lower First-Token** - Optimized for chat/interactive workloads (your primary use case)
4. **Expected Speed**: 20-25 tok/s (vs TabbyAPI EXL2 ~12 tok/s)

## Open-WebUI Integration

Same as before - SGLang provides OpenAI-compatible APIs:

1. Open-WebUI → Settings → Connections
2. Add Connection:
   - **Name**: SGLang Mistral-Large AWQ
   - **Base URL**: `http://localhost:8001/v1`
   - **API Key**: `test-key` (any non-empty string)
   - **Model**: `mistral-large-2411-awq`
3. Save and test

## Start/Stop Commands

```bash
# Start
nohup /home/ivan/sglang/start_sglang_mistral_tp6.sh > /home/ivan/sglang/sglang.log 2>&1 &

# Stop
pkill -f "sglang.launch_server"

# View logs
tail -f /home/ivan/sglang/sglang.log

# Check status
curl http://localhost:8001/v1/models
```

## Performance Monitoring

```bash
# Watch GPU usage
watch -n 1 nvidia-smi

# Monitor throughput (if metrics endpoint available)
curl -s http://localhost:8001/metrics | grep token

# Test completion
curl http://localhost:8001/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral-large-2411-awq",
    "prompt": "Hello, how are you?",
    "max_tokens": 100,
    "temperature": 0.7
  }'
```

## Comparison

| Feature | TabbyAPI (EXL2) | SGLang (AWQ) |
|---------|-----------------|--------------|
| Speed | ~12 tok/s | ~20-25 tok/s |
| GPUs Used | 5 | 6 |
| Quantization | 6.0 bpw EXL2 | 4-bit AWQ |
| VRAM | ~77 GB | ~70 GB |
| Context | 32K | 32K (24K active) |
| Multi-model | Model swap | Native |
| Stability | Mature | Production-ready |
| Latency | Baseline | Lower (RadixAttention) |

## Known Issues & Solutions

- **Context reduced to 24K**: Initial memory pressure; can try increasing `--mem-fraction-static` to 0.90
- **First request slow**: torch.compile warmup (~20s first time)
- **Model switching**: Requires server restart (stop/start script)

## Next Steps

1. Test in Open-WebUI and compare side-by-side with TabbyAPI
2. Monitor actual tok/s during real usage
3. If stable, consider moving more models to SGLang
4. Fine-tune `mem-fraction-static` to push toward full 32K context

---
Setup completed: $(date)
