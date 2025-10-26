# torch.compile - Should You Use It?

## Performance Impact

### WITHOUT torch.compile (Eager mode):
- ✓ Fast startup: 30-60 seconds
- ✓ Stable and predictable
- ✓ Easy to debug
- Decode speed: ~18-22 tok/s

### WITH torch.compile:
- ✗ Slow first startup: 15-30 minutes
- ✓ Fast subsequent startups: 1-2 minutes (uses cache)
- ✓ 10-30% faster generation
- Decode speed: ~20-28 tok/s

## Real Numbers (Estimated for your setup):

| Mode | Startup Time | Tok/s | Best For |
|------|-------------|--------|----------|
| Eager (no compile) | 45s | 19-22 | Development, testing, frequent restarts |
| Compiled | 20 mins (first) / 90s (cached) | 24-28 | Production, long-running servers |

## When to Use torch.compile:

✓ **YES** - Use it if:
- Server runs for days/weeks without restart
- You need maximum throughput
- You're serving production workloads
- Startup time doesn't matter

✗ **NO** - Skip it if:
- You're testing/experimenting
- You restart the server frequently
- 20% speed boost doesn't justify 20min wait
- You have stability issues

## For Your Situation:

**RECOMMENDATION: Start WITHOUT torch.compile**

Reasons:
1. You're still testing and comparing frameworks
2. You may need to restart/adjust configs frequently
3. The 19-22 tok/s without compile is already very good
4. AWQ quantization already provides excellent speed

**Later**: Once you settle on final config and want production deployment, enable it for that extra 20% boost.

## How to Enable/Disable:

### Disable (current - faster startup):
```bash
# Remove --enable-torch-compile from launch script
# Current script already has this removed
```

### Enable (when ready for production):
```bash
# Add to launch script:
--enable-torch-compile
```

### Compile with specific settings (advanced):
```bash
--enable-torch-compile \
--torch-compile-backend inductor \
--torch-compile-max-bs 32
```

## Compiled Kernel Cache Location:
`~/.triton/cache/` - Can delete to force recompile if issues occur
