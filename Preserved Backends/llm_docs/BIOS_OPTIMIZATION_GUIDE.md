# BIOS Optimization for ASRock Rack RomeD8-2T + EPYC 7F73

**Motherboard:** ASRock Rack RomeD8-2T  
**CPU:** AMD EPYC 7F73 (16-core, 3.2 GHz base)  
**RAM:** 512GB DDR4-3200 RDIMMs  
**GPU:** NVIDIA RTX PRO 6000 Blackwell  
**Hypervisor:** ESXi 8.0.3

## 🎯 Key Settings for LLM Inference Performance

### 1. PCIe Configuration (CRITICAL)

#### PCIe Slot Configuration
- **PCIe Gen:** Set to **Gen 4** (or Gen 5 if available)
  - Path: `Advanced` → `PCIe/PCI/PnP Configuration`
  - GPU benefits from maximum bandwidth
  - **Impact: High**

#### Above 4G Decoding
- **Setting:** **Enabled**
  - Required for large GPU memory (95GB VRAM)
  - Path: `Advanced` → `PCIe Configuration`
  - **Impact: Critical**

#### Resizable BAR (Re-BAR)
- **Setting:** **Enabled**
  - Allows CPU to access full GPU memory
  - Path: `Advanced` → `PCIe Configuration`
  - Check "Above 4G Decoding" is enabled first
  - **Impact: Medium (5-10% for LLM workloads)**

#### IOMMU
- **Setting:** **Enabled**
  - Required for ESXi GPU passthrough
  - Path: `Advanced` → `AMD CBS` → `NBIO Common Options`
  - **Impact: Critical for passthrough**

#### ACS (Access Control Services)
- **Setting:** **Enable ACS**
  - Improves PCIe device isolation for passthrough
  - Path: `Advanced` → `AMD CBS` → `NBIO Common Options`
  - **Impact: Medium**

### 2. CPU Configuration

#### Performance Mode
- **Power Policy:** **Max Performance**
  - Path: `Advanced` → `AMD CBS` → `CPU Common Options`
  - Prevents CPU throttling
  - **Impact: Medium**

#### C-States
- **Global C-State Control:** **Disabled**
  - Path: `Advanced` → `AMD CBS` → `CPU Common Options`
  - Reduces latency for VM operations
  - **Impact: Low-Medium**

#### SMT (Simultaneous Multi-Threading)
- **Setting:** **Enabled**
  - EPYC 7F73 has 16 cores / 32 threads
  - ESXi benefits from more threads
  - **Impact: Medium**

#### NUMA
- **Setting:** **Enabled** (default)
  - EPYC has 2x NUMA nodes
  - Keep enabled for optimal memory access
  - **Impact: Medium**

#### CPU Frequency
- **Core Performance Boost:** **Enabled**
  - Allows turbo to 4.0 GHz
  - Path: `Advanced` → `AMD CBS` → `CPU Common Options`
  - **Impact: Low (VM workload, not CPU-bound)**

### 3. Memory Configuration

#### Memory Clock
- **DRAM Frequency:** **3200 MHz** (max supported)
  - Should auto-configure for DDR4-3200
  - Path: `Advanced` → `AMD CBS` → `UMC Common Options`
  - **Impact: Low (LLM is GPU-bound)**

#### Memory Interleaving
- **Channel Interleaving:** **Enabled**
- **Bank Interleaving:** **Enabled**
  - Improves memory bandwidth
  - Path: `Advanced` → `AMD CBS` → `Memory Configuration`
  - **Impact: Low-Medium**

#### Power Down Enable
- **Setting:** **Disabled**
  - Prevents memory power saving modes
  - Slightly better latency
  - **Impact: Low**

### 4. Power Management

#### CPU Power Management
- **Power Supply Idle Control:** **Typical Current Idle**
  - Path: `Advanced` → `AMD CBS` → `CPU Common Options`
  - Better for sustained workloads
  - **Impact: Low**

#### PCIe Power Management
- **ASPM (Active State Power Management):** **Disabled**
  - Path: `Advanced` → `PCIe Configuration`
  - Prevents PCIe link throttling to GPU
  - **Impact: Medium**

### 5. Boot & Legacy Options

#### Fast Boot
- **Setting:** **Enabled** (optional)
  - Faster restarts
  - **Impact: None (just convenience)**

#### CSM (Compatibility Support Module)
- **Setting:** **Disabled**
  - UEFI-only boot
  - Modern OSes don't need CSM
  - **Impact: None**

### 6. ESXi-Specific BIOS Settings

#### SR-IOV (if available)
- **Setting:** Check if **Disabled**
  - Not needed for single-GPU passthrough
  - Can interfere with direct passthrough
  - **Impact: Low**

#### Virtualization
- **AMD-V (SVM Mode):** **Enabled**
  - Required for ESXi
  - Path: `Advanced` → `CPU Configuration`
  - **Impact: Critical**

#### NX (No Execute) Bit
- **Setting:** **Enabled**
  - Required for ESXi
  - **Impact: Critical**

## 📊 Expected Impact Summary

| Setting | Impact | Reason |
|---------|--------|--------|
| PCIe Gen 4 | High | Max GPU bandwidth |
| Above 4G Decoding | Critical | Large VRAM support |
| Resizable BAR | Medium | CPU→GPU memory access |
| IOMMU | Critical | GPU passthrough |
| ASPM Disabled | Medium | No PCIe throttling |
| C-States Disabled | Low-Medium | Lower latency |
| Max Performance | Medium | No CPU throttling |

## ⚠️ Important Notes

### 1. Resizable BAR Requirements
All three must be enabled:
1. Above 4G Decoding: Enabled
2. Resizable BAR: Enabled  
3. BIOS must be updated to latest version

### 2. After BIOS Changes
```bash
# In ESXi, verify passthrough still works:
esxcli hardware pci list | grep -i nvidia

# In VM, verify BAR size:
lspci -v -s 03:00.0 | grep "Memory at"
# Should show large region if Re-BAR working
```

### 3. Memory Configuration
With 512GB DDR4-3200 RDIMMs:
- Ensure all DIMMs in optimal slots for 8-channel mode
- Check BIOS POST for memory speed confirmation
- Should run at 3200 MHz (verify in BIOS)

## 🔧 Recommended BIOS Settings Checklist

**Before reboot, set these in BIOS:**

### Critical (Must Set)
- [x] PCIe Gen: 4 (or highest available)
- [x] Above 4G Decoding: Enabled
- [x] IOMMU: Enabled
- [x] AMD-V (SVM): Enabled
- [x] NX Bit: Enabled

### High Priority (Recommended)
- [x] Resizable BAR: Enabled
- [x] ASPM: Disabled
- [x] Global C-States: Disabled
- [x] CPU Performance: Max Performance

### Medium Priority (Nice to Have)
- [x] ACS: Enabled
- [x] Core Performance Boost: Enabled
- [x] SMT: Enabled
- [x] Memory Interleaving: Enabled

### Low Priority (Optional)
- [ ] Fast Boot: Enabled (convenience)
- [ ] CSM: Disabled (cleaner)

## 🚀 Post-BIOS Change Verification

After saving BIOS changes and booting:

### 1. In ESXi Host
```bash
# Check GPU passthrough
esxcli hardware pci list | grep -i nvidia

# Verify IOMMU groups
esxcli hardware pci pcipassthru list
```

### 2. In Ubuntu VM
```bash
# Check PCIe link
sudo lspci -vv -s 03:00.0 | grep "LnkSta:"
# Should show: Speed 16GT/s, Width x16

# Check if Re-BAR active
sudo lspci -v -s 03:00.0 | grep "Region 0"
# Large region indicates Re-BAR working

# Verify NUMA
numactl --hardware

# Check CPU frequency
grep MHz /proc/cpuinfo | head -5
```

### 3. Benchmark After Changes
```bash
# Run benchmark before and after
/tmp/bench_baseline.sh

# Compare results
# Expect 0-10% improvement (mainly from Re-BAR)
```

## 🎯 Realistic Expectations

**From BIOS optimizations alone:**
- Best case: +5-10% throughput (mostly from Re-BAR)
- Current: 22-25 tok/s
- After BIOS tuning: 23-27 tok/s
- Still limited by sm_120 kernel maturity

**Combined with software updates (future):**
- BIOS optimizations + FA4 sm_120 = 50-65 tok/s
- Everything stacks once kernels mature

## 📝 Current Auto-Start Configuration

After reboot, these start automatically:

1. **gpu-optimization.service**
   - Sets GPU clocks and persistence
   - Runs at boot

2. **sglang.service**
   - Starts SGLang with optimized config
   - Auto-restart on failure

3. **llm-router.service**
   - Starts multi-model router on port 8002
   - Auto-restart on failure

### Verify Services After Reboot
```bash
systemctl status gpu-optimization.service
systemctl status sglang.service
systemctl status llm-router.service

# Check router is responding
curl http://localhost:8002/health | jq .
```

## 🔗 Quick Reference

**Check if settings applied:**
```bash
# PCIe speed
sudo lspci -vv -s 03:00.0 | grep LnkSta

# Re-BAR status
sudo lspci -v -s 03:00.0 | grep "Region 0"

# NUMA nodes
numactl --hardware

# CPU frequency
watch -n1 "grep MHz /proc/cpuinfo | head -10"
```

---

**Created:** October 25, 2025  
**System:** ASRock Rack RomeD8-2T / EPYC 7F73 / 512GB DDR4-3200  
**Target:** Maximum LLM inference performance in ESXi VM
