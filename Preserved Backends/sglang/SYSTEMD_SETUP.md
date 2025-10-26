# SGLang Systemd Service Setup

## Service Management Commands

### Start SGLang
```bash
sudo systemctl start sglang
```

### Stop SGLang
```bash
sudo systemctl stop sglang
```

### Restart SGLang
```bash
sudo systemctl restart sglang
```

### Check Status
```bash
sudo systemctl status sglang
```

### Enable Auto-start on Boot
```bash
sudo systemctl enable sglang
```

### Disable Auto-start on Boot
```bash
sudo systemctl disable sglang
```

### View Logs
```bash
# Real-time logs
journalctl -u sglang -f

# Or from log file
tail -f /home/ivan/sglang/sglang.log
```

## Current Configuration

- **GPUs:** 0-1 (TP=2)
- **Port:** 8001
- **Context:** 32K tokens
- **Auto-restart:** Enabled (on failure)
- **Log file:** `/home/ivan/sglang/sglang.log`

## NVLink Configuration

### If you add NVLink bridges:
1. Shut down server: `sudo systemctl stop sglang`
2. Power off machine
3. Install NVLink bridges between GPU pairs
4. Power on
5. Check which GPUs are NVLinked:
   ```bash
   nvidia-smi nvlink --status
   ```
6. If NVLink pair is NOT GPUs 0-1, edit launch script:
   ```bash
   nano /home/ivan/sglang/start_sglang_mistral_tp2.sh
   # Change: export CUDA_VISIBLE_DEVICES=0,1
   # To your NVLink pair (e.g., 2,3 or 4,5)
   ```
7. Start server: `sudo systemctl start sglang`

### Expected Speed Improvement with NVLink:
- **Without NVLink (PCIe):** 22-25 tok/s (estimated)
- **With NVLink:** 25-30 tok/s (estimated)

NVLink provides ~600 GB/s bandwidth vs ~32 GB/s PCIe 3.0!

## Disabling Other Services

### To check what's auto-starting:
```bash
systemctl list-unit-files --state=enabled | grep -E "(comfy|tabby)"
```

### To disable ComfyUI (if it exists):
```bash
sudo systemctl disable comfyui
sudo systemctl stop comfyui
```

### To disable TabbyAPI (if it exists):
```bash
sudo systemctl disable tabbyapi
sudo systemctl stop tabbyapi
```

## Service File Location
`/etc/systemd/system/sglang.service`

To edit:
```bash
sudo nano /etc/systemd/system/sglang.service
sudo systemctl daemon-reload  # After editing
```
