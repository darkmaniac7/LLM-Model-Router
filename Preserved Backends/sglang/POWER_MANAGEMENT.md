# GPU Power Management Guide

## Performance vs Power Consumption

### Test Results:
- **165W (default):** ~20 tok/s (baseline)
- **180W:** ~20.5 tok/s (current setting) ✅
- **250W:** ~29.5 tok/s (UPS overload ❌)

### Recommendation: 180W is the sweet spot!
- Minimal performance loss vs 250W
- UPS-friendly
- Still faster than vLLM
- More efficient cooling

## Setting GPU Power Limits

### Current Power Limits:
```bash
nvidia-smi -q -d POWER | grep "Power Limit"
```

### Set Power Limit for All GPUs (Temporary - resets on reboot):
```bash
# Set to 180W for GPUs 0-3 (in use by SGLang)
sudo nvidia-smi -i 0 -pl 180
sudo nvidia-smi -i 1 -pl 180
sudo nvidia-smi -i 2 -pl 180
sudo nvidia-smi -i 3 -pl 180

# Or all at once:
for i in 0 1 2 3; do sudo nvidia-smi -i $i -pl 180; done
```

### Set Power Limit Permanently (survives reboot):
```bash
# Create systemd service
sudo nano /etc/systemd/system/nvidia-power-limit.service
```

Add this content:
```ini
[Unit]
Description=Set NVIDIA GPU Power Limits
After=nvidia-persistenced.service

[Service]
Type=oneshot
ExecStart=/usr/bin/nvidia-smi -i 0 -pl 180
ExecStart=/usr/bin/nvidia-smi -i 1 -pl 180
ExecStart=/usr/bin/nvidia-smi -i 2 -pl 180
ExecStart=/usr/bin/nvidia-smi -i 3 -pl 180
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Enable it:
```bash
sudo systemctl daemon-reload
sudo systemctl enable nvidia-power-limit
sudo systemctl start nvidia-power-limit
```

### Check Current Power Draw:
```bash
watch -n 1 'nvidia-smi --query-gpu=index,name,power.draw,power.limit --format=csv'
```

## Power Optimization Tips

### 1. Adjust Power per GPU
If UPS is still struggling, you can be more granular:
```bash
# GPUs 0-3 (in use): 180W
# GPUs 4-5 (idle): 100W (save power)
sudo nvidia-smi -i 0,1,2,3 -pl 180
sudo nvidia-smi -i 4,5 -pl 100
```

### 2. Dynamic Power Adjustment
Lower power during idle, raise during heavy use:
```bash
# Idle/light use (maintain responsiveness)
for i in 0 1 2 3; do sudo nvidia-smi -i $i -pl 165; done

# Heavy workload (max performance)
for i in 0 1 2 3; do sudo nvidia-smi -i $i -pl 180; done
```

### 3. Monitor UPS Load
```bash
# Install nut (Network UPS Tools) if not already
sudo apt install nut

# Check UPS status
upsc <your_ups_name>
```

## Performance vs Power Trade-offs

| Power Limit | Tok/s | Power Draw (est.) | Use Case |
|-------------|-------|-------------------|----------|
| 165W (stock) | 20 | ~660W (4 GPUs) | Baseline |
| 180W | 20.5 | ~720W (4 GPUs) | **Optimal** ✅ |
| 200W | 22-23 | ~800W (4 GPUs) | High performance |
| 250W | 29.5 | ~1000W (4 GPUs) | Max (UPS risk) ❌ |

## Current Recommendation

**Stick with 180W:**
- Good performance (20.5 tok/s)
- UPS-friendly
- Lower heat/noise
- Better efficiency
- Still 40% faster than vLLM baseline

## torch.compile Impact on Power

With torch.compile enabled:
- Same power draw
- Higher efficiency (more work per watt)
- Expected: 23-25 tok/s at 180W

## Calculating Total System Power

```
SGLang (4x 3090 @ 180W) = 720W
+ CPU, RAM, drives, fans  = ~200W
+ 10% inefficiency       = ~100W
─────────────────────────────────
Total system draw        ≈ 1020W

Your UPS should be rated for 1500W+ for safety margin.
```

If UPS is rated lower, keep GPUs at 165-170W.
