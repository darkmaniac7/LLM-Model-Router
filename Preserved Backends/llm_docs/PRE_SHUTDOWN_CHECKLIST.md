# Pre-Shutdown Checklist - Blackwell System

**Date:** 2025-10-25  
**System:** Ubuntu 24.04 with RTX 6000 Pro Blackwell

## ✅ Completed Updates

### 1. Multi-Backend Router (v3.2.0)
- ✅ Added llama.cpp support for GGUF models
- ✅ Fixed backend cleanup (stops all services + kills orphaned processes)
- ✅ Added 2 GGUF models: Behemoth R1 123B, Magnum Diamond 123B
- ✅ Updated documentation in `/home/ivan/llm_docs/MULTI_BACKEND_ROUTER.md`
- ✅ Package ready: `/tmp/multi-backend-llm-router-v3.2.0-final.tar.gz`

### 2. SGLang CPU Usage Fix
- ✅ Added `--sleep-on-idle` to all 5 SGLang startup scripts
- ✅ Reduces idle CPU from 350% to ~10-20%
- ✅ Documentation in `/home/ivan/llm_docs/CPU_USAGE_FIX.md`
- ✅ Scripts updated:
  - `start_sglang_deepseek_blackwell.sh`
  - `start_sglang_katdev_blackwell.sh`
  - `start_sglang_llama33_blackwell.sh`
  - `start_sglang_magnum_blackwell.sh`
  - `start_sglang_mistral_blackwell.sh`

### 3. llama.cpp Integration
- ✅ Built with CUDA 12.9, sm_90 architecture
- ✅ Location: `/home/ivan/llama.cpp/build/`
- ✅ GGUF models downloaded in `/home/ivan/models/gguf/`
- ✅ Startup scripts created for both models
- ✅ systemd service configured

### 4. Documentation
- ✅ Created `MULTI_BACKEND_ROUTER.md` (comprehensive guide)
- ✅ Created `CPU_USAGE_FIX.md` (SGLang idle CPU issue)
- ✅ Created `INSTALL_CHECKLIST.md` in package
- ✅ Created `CHANGELOG.md` in package

## Current System State

### Services (All Enabled for Auto-Start)
```
✓ model-router.service  - Running, port 8002
✓ sglang.service        - Running, port 30000 (with --sleep-on-idle)
✓ tabbyapi.service      - Enabled, port 5000
✓ llamacpp.service      - Enabled, port 8085
```

### Active Model
```
magnum-v4-123b-awq (SGLang/AWQ) on port 30000
```

### Available Models (8 total)
1. mistral-large-2411-awq (SGLang/AWQ)
2. llama-3.3-70b-awq (SGLang/AWQ)
3. deepseek-r1-distill-70b-awq (SGLang/AWQ)
4. magnum-v4-123b-awq (SGLang/AWQ) **← Active**
5. kat-dev-awq-8bit (SGLang/AWQ)
6. monstral-123b-exl2-4bpw (TabbyAPI/EXL2)
7. behemoth-r1-123b-iq4nl (llama.cpp/GGUF)
8. magnum-diamond-123b-iq4nl (llama.cpp/GGUF)

## Files for GitHub/Backup

### Package
`/tmp/multi-backend-llm-router-v3.2.0-final.tar.gz` (11KB)

Contains:
- router.py (updated with llama.cpp support)
- install.sh
- README.md
- CHANGELOG.md
- INSTALL_CHECKLIST.md
- LICENSE
- systemd service templates
- Example startup scripts

### Documentation
`/home/ivan/llm_docs/`
- MULTI_BACKEND_ROUTER.md (NEW)
- CPU_USAGE_FIX.md (NEW)
- All other existing docs preserved

### Router Script
`/home/ivan/model_router_blackwell.py` (20KB)

### Startup Scripts
`/home/ivan/sglang/*.sh` (all updated with --sleep-on-idle)

## Post-Reboot Verification Steps

1. **Check Services:**
   ```bash
   systemctl status model-router sglang
   ```

2. **Verify Router:**
   ```bash
   curl http://localhost:8002/health
   curl http://localhost:8002/v1/models
   ```

3. **Check CPU Usage (after 2min warmup):**
   ```bash
   top -b -n 1 | grep sglang
   # Should show low %CPU when idle
   ```

4. **Test Model Switching:**
   - Try switching to llama.cpp model in Open-WebUI
   - Watch for loading status
   - Check GPU memory clears properly: `nvidia-smi`

5. **Check GPU:**
   ```bash
   nvidia-smi
   # Should show active model loaded
   ```

## Known Post-Reboot Behavior

- Services start automatically
- Router may take 10-15s to be ready
- First model load after boot takes ~30-60s
- SGLang CPU will be high for ~2min during warmup, then drop to <10%
- llama.cpp models take longer to load (60-90s) due to GGUF size

## If Something Breaks

### Router Won't Start
```bash
journalctl -u model-router -n 50
# Check for port conflicts or Python errors
```

### Backend Won't Start
```bash
systemctl status sglang
journalctl -u sglang -n 50
# Check model paths and VRAM
```

### High CPU on SGLang
```bash
grep "sleep-on-idle" /home/ivan/sglang/start_sglang_*_blackwell.sh
# All should show the flag
```

### llama.cpp Won't Load
```bash
# Check binary exists
ls -lh /home/ivan/llama.cpp/build/bin/llama-server

# Check models
ls -lh /home/ivan/models/gguf/*/

# Test manually
/home/ivan/sglang/start_llamacpp_behemoth_blackwell.sh
```

## Next Steps on New System

1. Extract package: `tar -xzf multi-backend-llm-router-v3.2.0-final.tar.gz`
2. Follow `INSTALL_CHECKLIST.md`
3. Verify installer works correctly
4. Test model switching across all backends
5. Confirm CPU usage is low with --sleep-on-idle

---

**System Ready for Shutdown!** 🎉

All updates applied, services configured, documentation complete.
