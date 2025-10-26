# Tensor Parallel (TP) vs Pipeline Parallel (PP)

## Your Current Setup: TP=4
**How it works:**
- Model split HORIZONTALLY across 4 GPUs
- Each layer distributed across all 4 GPUs
- GPUs work in PARALLEL on same tokens
- Fast for single requests

**Speed:** 20+ tok/s ✅

## Alternative: PP=6 (Pipeline Parallel)
**How it works:**
- Model split VERTICALLY across 6 GPUs
- GPU 0: Layers 1-17
- GPU 1: Layers 18-34
- GPU 2: Layers 35-51
- ... etc
- Tokens flow SEQUENTIALLY through pipeline

**Speed:** 8-12 tok/s ❌ (MUCH SLOWER!)

## Why PP is Slower for You:

### Latency per Token:
```
TP=4:  All GPUs work together → 1 step per token
PP=6:  Token must visit 6 GPUs sequentially → 6 steps per token
```

### Example Timeline:
**TP=4:**
```
Token 1: [GPU0+1+2+3 together] → Done in 50ms
Token 2: [GPU0+1+2+3 together] → Done in 50ms
```

**PP=6:**
```
Token 1: GPU0 → GPU1 → GPU2 → GPU3 → GPU4 → GPU5 → Done in 300ms
Token 2: Waits for Token 1 to clear pipeline...
```

## When PP is Better:

✅ **High throughput batching** (100+ concurrent users)
- Can fill pipeline with many requests
- Throughput improves, but latency still high

✅ **Model too big for TP**
- If model doesn't fit in TP memory
- Last resort for huge models

## When TP is Better (Your Case):

✅ **Low latency per request** (1-10 concurrent users)
✅ **Interactive use** (chat, coding assistance)
✅ **Single user / small team**
✅ **Streaming responses** (feels instant)

## Performance Comparison (Your Hardware):

| Config | Tok/s | Latency | Throughput | Best For |
|--------|-------|---------|------------|----------|
| TP=4 (current) | 20+ | LOW ✅ | Medium | You! |
| TP=2 | 22-25 | LOWER ✅ | Medium | Single user |
| PP=6 | 8-12 | HIGH ❌ | High* | 100+ users |
| TP=2 + PP=3 | 15-18 | Medium | High | Mixed workload |

*Only if you have 50-100+ concurrent requests filling the pipeline

## Recommendation for You:

**Stick with TP=4** (or try TP=2)

Your use case (weeks uptime, personal/small team) benefits from:
- Low latency ✅
- Fast streaming ✅
- Good single-request speed ✅

PP=6 would make it feel sluggish and slow, even though theoretical throughput
might be higher with 100+ concurrent users (which you don't have).

## To Try TP=2 (Potentially Faster):

```bash
# Edit start script, change:
--tp 4
# to:
--tp 2

# Expected: 22-25 tok/s (less cross-GPU communication overhead)
# Tradeoff: Uses only 2 GPUs instead of 4
```

TP=2 might actually be faster than TP=4 because of PCIe bandwidth limitations!
