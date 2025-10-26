# Blackwell GB200 Performance Optimization Plan

**Goal:** Extract maximum performance from current Triton backend setup
**Current:** ~22-25 tok/s @ 500W
**Target:** 30-35 tok/s @ 550-600W (realistic without FA4)

## 🎯 Optimization Strategies

### 1. Lock GPU Clocks (Highest Impact)

#### Why It Helps
- Prevents GPU frequency throttling
- Eliminates clock ramp-up latency
- Maintains consistent power draw
- Can unlock 10-20% more performance

#### Check Current Clock Behavior
```bash
# Monitor clocks during inference
nvidia-smi --query-gpu=clocks.gr,clocks.mem,power.draw --format=csv -l 1

# Check available clock speeds
nvidia-smi -q -d SUPPORTED_CLOCKS | grep "Memory\|Graphics" | head -20
```

#### Lock to Maximum Clocks
```bash
# Enable persistence mode (required)
nvidia-smi -pm 1

# Lock memory clock to max (crucial for LLM inference)
nvidia-smi -i 0 --lock-memory-clocks=<MAX_MHZ>

# Lock GPU clock to max
nvidia-smi -i 0 --lock-gpu-clocks=<MIN_MHZ>,<MAX_MHZ>

# Example (replace with actual values):
nvidia-smi -i 0 --lock-memory-clocks=13365
nvidia-smi -i 0 --lock-gpu-clocks=2500,2800

# Verify
nvidia-smi --query-gpu=clocks.gr,clocks.mem --format=csv
```

**Expected gain:** 10-15% throughput increase

#### Reset If Needed
```bash
# Reset clocks
nvidia-smi -i 0 -rgc  # Reset GPU clock
nvidia-smi -i 0 -rmc  # Reset memory clock

# Disable persistence
nvidia-smi -pm 0
```

---

### 2. Increase Power Limit (Medium Impact)

#### Current Status
```bash
# Check current power settings
nvidia-smi --query-gpu=power.draw,power.limit,power.max_limit --format=csv
```

#### Increase to Maximum Safe Level
```bash
# Check max allowed power
nvidia-smi -q -d POWER | grep "Max Power"

# Set to 600W (or max allowed)
nvidia-smi -i 0 -pl 600

# Verify
nvidia-smi --query-gpu=power.limit --format=csv
```

**Current:** ~500W draw with unlocked limit  
**After optimization:** Should see 550-600W with locked clocks

**Expected gain:** 5-10% with locked clocks + higher power

---

### 3. Optimize SGLang Launch Parameters

#### Current Config
```bash
--mem-fraction-static 0.88
--chunked-prefill-size 8192
--attention-backend triton
```

#### Try These Tweaks

**A. Increase Chunked Prefill**
```bash
--chunked-prefill-size 16384  # or 32768
```
Larger chunks = better GPU utilization during prefill

**B. Tune Memory Fraction**
```bash
--mem-fraction-static 0.92  # Use more VRAM for KV cache
```
More cache = fewer recomputations

**C. Add Batch Optimization Flags**
```bash
--max-running-requests 8  # Allow some batching
--schedule-policy fcfs    # First-come-first-serve
```

**D. Disable Sleep-On-Idle** (if using)
```bash
# Remove --sleep-on-idle flag
```
Keeps GPU ready, no wake-up latency

#### Test Script with Optimizations
```bash
#!/bin/bash
source /home/ivan/sglang/sglang-env/bin/activate
export CUDA_VISIBLE_DEVICES=0

python -m sglang.launch_server \
    --model-path /home/ivan/models/Mistral-Large-Instruct-2411-AWQ \
    --host 0.0.0.0 \
    --port 30000 \
    --tp 1 \
    --attention-backend triton \
    --served-model-name mistral-large-2411-awq \
    --mem-fraction-static 0.92 \
    --chunked-prefill-size 16384 \
    --max-running-requests 8 \
    --schedule-policy fcfs \
    --log-level info \
    --log-requests
```

**Expected gain:** 5-10% combined

---

### 4. Environment Variable Tuning

#### CUDA-Specific Optimizations
```bash
# Add to startup scripts
export CUDA_LAUNCH_BLOCKING=0              # Async kernel launch
export CUDA_DEVICE_MAX_CONNECTIONS=32      # More concurrent streams
export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True,max_split_size_mb:512"

# For Triton specifically
export TRITON_CACHE_DIR=/tmp/triton_cache
export TRITON_KERNEL_CACHE_SIZE=10000
```

#### Add to Start Script
```bash
# At top of start_sglang_mistral_blackwell.sh
export CUDA_LAUNCH_BLOCKING=0
export CUDA_DEVICE_MAX_CONNECTIONS=32
export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True,max_split_size_mb:512"
export TRITON_CACHE_DIR=/tmp/triton_cache
```

**Expected gain:** 3-5%

---

### 5. Kernel-Level Optimizations

#### Check Current Triton Kernels
```bash
# Monitor kernel compilation
journalctl -u sglang.service -f | grep -i "triton\|compile\|kernel"
```

#### Pre-compile Triton Kernels
On first run with new settings, Triton compiles kernels. Subsequent runs are faster.

**Warm-up procedure:**
```bash
# Start model
systemctl restart sglang.service

# Wait 60s for load

# Send 10 warm-up requests with varying lengths
for i in {10..100..10}; do
  curl -X POST http://localhost:30000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"mistral-large-2411-awq\",
      \"messages\": [{\"role\": \"user\", \"content\": \"$(head -c $i < /dev/urandom | base64)\"}],
      \"max_tokens\": 100
    }" > /dev/null 2>&1
done

echo "Kernels warmed up!"
```

**Expected gain:** Faster first requests, consistent performance

---

### 6. System-Level Optimizations

#### A. CPU Governor
```bash
# Set to performance mode
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo performance | sudo tee $cpu
done

# Verify
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```

#### B. Disable CPU Power Saving
```bash
# Disable C-states (if not needed)
sudo cpupower idle-set -D 0

# Or via BIOS (better)
```

#### C. Increase File Descriptors
```bash
# For systemd service, add to [Service] section:
LimitNOFILE=65535
```

**Expected gain:** 1-3% (reduces system overhead)

---

### 7. Profile-Guided Optimization

#### Benchmark Before Changes
```bash
# Save baseline
cat > /tmp/bench_baseline.sh << 'BENCH'
#!/bin/bash
START=$(date +%s)
TOKENS=0

for i in {1..10}; do
  RESPONSE=$(curl -s -X POST http://localhost:30000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
      "model": "mistral-large-2411-awq",
      "messages": [{"role": "user", "content": "Write a detailed essay about machine learning."}],
      "max_tokens": 500
    }')
  
  COUNT=$(echo $RESPONSE | jq '.usage.completion_tokens')
  TOKENS=$((TOKENS + COUNT))
done

END=$(date +%s)
ELAPSED=$((END - START))
TOKPS=$(echo "scale=2; $TOKENS / $ELAPSED" | bc)

echo "Tokens: $TOKENS"
echo "Time: ${ELAPSED}s"
echo "Tok/s: $TOKPS"
BENCH

chmod +x /tmp/bench_baseline.sh
/tmp/bench_baseline.sh > /tmp/baseline_results.txt
```

#### Test Each Change
After each optimization:
```bash
/tmp/bench_baseline.sh > /tmp/test_results.txt
diff /tmp/baseline_results.txt /tmp/test_results.txt
```

---

## 🚀 Recommended Implementation Order

### Phase 1: Low-Risk, High-Impact (Do First)
1. **Lock GPU clocks** - Biggest gain, easy to revert
2. **Increase power limit to 600W** - Safe, immediate benefit
3. **Set CPU to performance** - System-level, no model restart

**Expected: 25-28 tok/s**

### Phase 2: SGLang Parameter Tuning
1. Increase chunked-prefill to 16384
2. Bump mem-fraction to 0.92
3. Add environment variables
4. Remove sleep-on-idle

**Expected: 28-32 tok/s**

### Phase 3: Advanced (If Needed)
1. Tune batch parameters
2. Profile with different prefill sizes
3. Test alternative schedule policies

**Expected: 32-35 tok/s**

---

## 📊 Monitoring & Validation

### During Testing
```bash
# Terminal 1: Watch GPU
watch -n 0.5 'nvidia-smi --query-gpu=clocks.gr,clocks.mem,power.draw,utilization.gpu --format=csv,noheader'

# Terminal 2: Monitor SGLang
journalctl -u sglang.service -f

# Terminal 3: Run benchmarks
/tmp/bench_baseline.sh
```

### Success Metrics
- **Clock stability:** No fluctuation during inference
- **Power draw:** Consistently 550-600W (not bouncing)
- **GPU utilization:** Steady 100% SM
- **Tok/s:** 30-35 tok/s (up from 22-25)

---

## ⚠️ Safety Notes

### GPU Clocks
- Always monitor temperatures
- Locked clocks = sustained high power
- Ensure adequate cooling (fans, room temp)
- If temps >85°C, unlock clocks immediately

### Power Limit
- 600W is within spec for GB200
- Monitor PSU capacity (ensure >800W available)
- Check power cable ratings (should be 16AWG+)

### Revert Script
```bash
#!/bin/bash
# Save as /home/ivan/sglang/reset_gpu.sh

echo "Resetting GPU to defaults..."

# Unlock clocks
nvidia-smi -i 0 -rgc
nvidia-smi -i 0 -rmc

# Reset power limit (to default)
nvidia-smi -i 0 -pl 500

# Disable persistence
nvidia-smi -pm 0

echo "GPU reset complete"
nvidia-smi
```

---

## 🎯 Realistic Target

**Current Baseline:**
- 22-25 tok/s @ 500W (unlocked, varying clocks)

**With All Optimizations:**
- 30-35 tok/s @ 580-600W (locked clocks, tuned params)

**Why Not More?**
- Triton backend fundamentally limited on sm_120
- No torch.compile (adds startup time)
- Waiting for FA4 sm_120 support for 2-3x jump

**This is ~40% improvement while staying stable!**

---

## 📝 Next Steps

1. Start with Phase 1 (lock clocks + power)
2. Benchmark before/after each change
3. Document results in performance_log.txt
4. Revert if unstable
5. Update docs with findings

Once FA4 supports sm_120, these optimizations will compound with better kernels for even bigger gains.

---

**Created:** October 25, 2025  
**Status:** Ready to test  
**Expected Gain:** 30-50% throughput increase
