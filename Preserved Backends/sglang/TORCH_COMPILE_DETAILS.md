# torch.compile Cache Behavior

## How It Works

### First Time (Per Model):
- Compiles for 15-20 minutes
- Caches compiled kernels to `~/.triton/cache/`
- Cache is **model-specific** based on:
  - Model architecture
  - Batch sizes configured
  - Context length
  - Quantization type
  - GPU type

### Subsequent Restarts (Same Config):
- Reads from cache: ~90 seconds startup
- **No recompilation needed!**
- Fast startup like eager mode (but faster inference)

### When It Recompiles:
- ❌ Different model (e.g., switch to different Mistral variant)
- ❌ Change context length (e.g., 24K → 32K)
- ❌ Change TP size (e.g., TP=4 → TP=2)
- ❌ Change batch size configs
- ✅ Same model, same config = uses cache

## For Your Use Case (Weeks Uptime):

**torch.compile is PERFECT for you!**

Here's why:
1. ✅ You run for weeks - one-time 20min compile is negligible
2. ✅ After first compile, restarts are ~90s (uses cache)
3. ✅ You get 20-25% speed boost (20 tok/s → 24-25 tok/s)
4. ✅ Once stable, you rarely restart

## Recommendation:

**Enable torch.compile for production!**

Steps:
1. Wait until you're happy with current config (stable)
2. Add `--enable-torch-compile` to launch script
3. First start: go make coffee for 20 mins ☕
4. After that: enjoy 24-25 tok/s for weeks!
5. Any restart uses cache: 90s startup

## Cache Location:
```bash
# View cache
ls -lh ~/.triton/cache/

# Clear cache if needed (forces recompile)
rm -rf ~/.triton/cache/*
```

## Bottom Line:
- **Short-lived testing:** Skip it (current setup perfect)
- **Production (weeks uptime):** Enable it (20% faster for free after one-time wait)

Since you run for weeks, the 20min compile cost pays for itself in hours!
