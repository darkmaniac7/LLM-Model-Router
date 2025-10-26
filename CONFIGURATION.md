# Configuration Guide

This guide helps you configure the Multi-Backend LLM Router for your system.

## Quick Setup

After running `sudo ./install.sh`, you need to:

1. **Edit model definitions**: `/etc/llm-router/models.yml`
2. **Create startup scripts** for your models (examples in `scripts/`)
3. **Configure TabbyAPI path** (if using TabbyAPI)

## Model Configuration

### For SGLang Models

Create a startup script for each model:

```bash
#!/bin/bash
# Example: start_my_model.sh
python -m sglang.launch_server \
    --model-path /path/to/your/model \
    --port 30000 \
    --host 0.0.0.0
```

Add to `/etc/llm-router/models.yml`:

```yaml
my-model-name:
  backend: sglang
  script: /path/to/start_my_model.sh
  service: sglang.service
```

### For llama.cpp Models

Use the example scripts in `scripts/` as templates. They support environment variables:

```bash
# Copy and customize the example
cp scripts/start_llamacpp_behemoth_blackwell.sh ~/my_model_start.sh

# Edit the script - set your paths
nano ~/my_model_start.sh
```

The script uses `$HOME` automatically, so it works for any user:

```bash
LLAMACPP_DIR="${LLAMACPP_DIR:-$HOME/llama.cpp}"
MODEL_PATH="${MODEL_PATH:-$HOME/models/gguf/YourModel.gguf}"
```

Or set environment variables in your systemd service:

```ini
[Service]
Environment="LLAMACPP_DIR=/opt/llama.cpp"
Environment="MODEL_PATH=/models/my-model.gguf"
```

### For TabbyAPI Models

The router automatically searches for TabbyAPI config in:
1. `~/tabbyAPI/config.yml`
2. `/opt/tabbyAPI/config.yml`
3. `/etc/tabbyapi/config.yml`

Add to `/etc/llm-router/models.yml`:

```yaml
my-exl2-model:
  backend: tabbyapi
  script: null
  service: tabbyapi.service
  model_name: Model-Directory-Name
```

The `model_name` should match the directory name in your TabbyAPI models folder.

## Path Configuration Tips

### Using Home Directory

Scripts use `$HOME` which expands to the current user's home directory:
- `$HOME/llama.cpp` → `/home/youruser/llama.cpp`
- `$HOME/models` → `/home/youruser/models`

### Using Environment Variables

Set in systemd service or shell:

```bash
export LLAMACPP_DIR=/custom/path/llama.cpp
export MODEL_PATH=/custom/path/model.gguf
```

### Absolute Paths

You can also use absolute paths directly in startup scripts:

```bash
cd /opt/llama.cpp/build
exec ./bin/llama-server -m /data/models/my-model.gguf ...
```

## Testing Your Configuration

After editing `/etc/llm-router/models.yml`:

```bash
# Restart the router
sudo systemctl restart llm-router

# Check if models are listed
curl http://localhost:8002/v1/models

# View logs
sudo journalctl -u llm-router -f
```

## Common Issues

### "TabbyAPI config not found"

Make sure TabbyAPI is installed and config.yml exists in one of:
- `~/tabbyAPI/config.yml`
- `/opt/tabbyAPI/config.yml`
- `/etc/tabbyapi/config.yml`

### "Script not found"

- Check that startup scripts have execute permissions: `chmod +x /path/to/script.sh`
- Verify paths in scripts are correct for your system
- Test scripts manually: `bash /path/to/script.sh`

### Model won't load

- Check systemd service status: `sudo systemctl status sglang` (or tabbyapi/llamacpp)
- View service logs: `sudo journalctl -u sglang -n 50`
- Verify model files exist at specified paths

## Security Note

The router requires root/sudo access because it manages systemd services. Always review startup scripts before running them.
