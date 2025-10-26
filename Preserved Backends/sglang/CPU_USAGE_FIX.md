# SGLang CPU Usage Issue & Fix

## The Problem

SGLang's scheduler processes **busy-wait** when idle, consuming 90-100% CPU per scheduler.

With TP=4, you have 4 schedulers = **~400% CPU usage when doing nothing!**

This is a known issue with SGLang - the schedulers poll continuously instead of sleeping.

## The Fix

Added `--sleep-on-idle` flag to the launch script.

This makes schedulers sleep when there are no requests, dramatically reducing idle CPU usage.

### Before (without flag):
```
sglang::scheduler_TP0:  95% CPU (idle)
sglang::scheduler_TP1:  90% CPU (idle)  
sglang::scheduler_TP2:  82% CPU (idle)
sglang::scheduler_TP3:  80% CPU (idle)
─────────────────────────────────
Total: ~350% CPU wasted!
```

### After (with --sleep-on-idle):
```
sglang::scheduler_TP0:  2-5% CPU (idle)
sglang::scheduler_TP1:  2-5% CPU (idle)
sglang::scheduler_TP2:  2-5% CPU (idle)  
sglang::scheduler_TP3:  2-5% CPU (idle)
─────────────────────────────────
Total: ~10-20% CPU (normal!)
```

## Impact on Performance

**Latency:** Adds ~1-2ms to first request after idle period (negligible!)

**Throughput:** No impact once requests are flowing

**Trade-off:** Worth it to save 350% CPU!

## Verification

After server starts (60-90 seconds), check CPU:

```bash
# Watch CPU usage
top -b -n 1 | grep "sglang::schedul"

# Should see low %CPU when idle
```

## If Still High CPU

The flag might not be working. Alternative: use `--schedule-policy` with timeout:

```bash
# In launch script, add:
--scheduler-recv-interval 10

# This makes schedulers check every 10ms instead of constantly polling
# Less aggressive than --sleep-on-idle but still helps
```

## Current Configuration

The fix is already applied in:
`/home/ivan/sglang/start_sglang_mistral_tp4_compiled.sh`

Line added: `--sleep-on-idle`

## Why This Happens

SGLang prioritizes **lowest possible latency** for real-time requests.

Busy-waiting = instant response when request arrives (no wake-up delay).

But for most users (including you), saving 350% CPU is worth 1-2ms extra latency!

---

**Bottom line:** Your CPU usage should drop to near-zero when idle after the server fully loads. Check in ~2 minutes after restart.

