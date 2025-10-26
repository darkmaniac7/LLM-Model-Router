# NVLink Installation Guide

## ⚠️ IMPORTANT: Must Shutdown System

**You CANNOT install NVLink bridges with the system running!**

NVLink bridges are physical connectors that attach to the top of the GPUs.
The system must be powered off completely.

---

## Installation Procedure

### 1. Stop SGLang Service (Optional - will stop on shutdown anyway)
```bash
sudo systemctl stop sglang
```

### 2. Shutdown System Completely
```bash
sudo shutdown -h now
```

Wait for system to fully power down (fans stop, lights off).

### 3. Install NVLink Bridges

**Physical installation:**
- Open case
- Locate the NVLink connectors on top of each GPU
- RTX 3090 has 2 NVLink connectors per card
- Each bridge connects 2 GPUs

**Typical configuration for 6 GPUs:**
- Bridge 1: GPU 0 ↔ GPU 1
- Bridge 2: GPU 2 ↔ GPU 3
- (GPU 4 & 5 either linked or not, depending on your needs)

**Important:**
- Align bridge carefully with connectors
- Press down firmly until it clicks/locks
- Should be secure and not wobble

### 4. Power On System
```bash
# Just press power button
```

### 5. Verify NVLink After Boot

Once system is back up, check NVLink status:

```bash
# Check if NVLink is detected
nvidia-smi nvlink --status

# Should show something like:
# GPU 0: 2 NVLink Links (to GPU 1)
# GPU 1: 2 NVLink Links (to GPU 0)
# etc.
```

### 6. Check SGLang Service

The service should auto-start on boot (we enabled it):

```bash
systemctl status sglang

# If torch.compile was interrupted, it will resume compilation
# Check logs:
tail -f /home/ivan/sglang/sglang.log
```

---

## What to Expect After NVLink

### Performance Gains:

**Before NVLink (PCIe 3.0):**
- ~32 GB/s bandwidth between GPUs
- Good for TP=4

**After NVLink:**
- ~600 GB/s bandwidth per bridge
- 18x faster GPU-to-GPU communication!
- Better for TP=2 and TP=4

### Expected Speed Improvement:

With torch.compile + NVLink:
- **At 250W:** 42-45 tok/s (vs 38-40 without NVLink)
- **At 390W:** 55-60 tok/s (vs 50-55 without NVLink)

---

## If torch.compile Was Interrupted

**Don't worry!** The compiled kernels are saved incrementally.

When SGLang restarts:
- It will check `~/.triton/cache/`
- Use any already-compiled kernels
- Only recompile what's missing
- Should be faster than first time

---

## Troubleshooting

### NVLink Not Detected After Install:

```bash
# Check GPU detection
nvidia-smi

# Check NVLink status
nvidia-smi nvlink --status

# If no NVLink shown:
# - Reseat the bridges (power off, reinstall)
# - Check GPU spacing (must be adjacent slots)
# - Verify bridge orientation (notch should align)
```

### SGLang Won't Start After Reboot:

```bash
# Check logs
journalctl -u sglang -n 50

# Or
tail -100 /home/ivan/sglang/sglang.log

# If OOM errors, bridges might have changed GPU numbering
# Check nvidia-smi for GPU order
```

---

## Current Plan

### Right Now:
- torch.compile is running (10-15 mins left)
- Server is compiling optimized kernels
- You can wait for it to finish OR shutdown now

### Option A: Wait for Compilation to Finish
```bash
# Monitor until done
tail -f /home/ivan/sglang/sglang.log

# When you see "Server is ready" or API responds:
curl -s http://localhost:8001/v1/models

# Then shutdown:
sudo shutdown -h now
```

### Option B: Shutdown Now
```bash
# Stop service
sudo systemctl stop sglang

# Shutdown
sudo shutdown -h now

# Compilation will resume after NVLink install
```

**Recommendation:** Option B (shutdown now) is fine. The compilation will resume automatically and you'll waste less time waiting.

---

## After Installation Checklist

✅ Boot system  
✅ Check NVLink: `nvidia-smi nvlink --status`  
✅ Verify service: `systemctl status sglang`  
✅ Wait for compilation to finish (if not done)  
✅ Test performance: `/home/ivan/sglang/test_tokps.sh`  
✅ Enjoy 42-45 tok/s! 🚀  

