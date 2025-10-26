# TabbyAPI Authentication Fix

## Current Issue

TabbyAPI requires API key authentication, but the router's health check doesn't pass credentials, causing 401 errors.

## Symptoms

- TabbyAPI service starts successfully
- Health checks fail with "Please provide an API key"
- Router times out waiting for backend to be ready
- Model never loads to GPU

## Quick Fix Options

### Option 1: Disable TabbyAPI Authentication (Simplest)

Edit `/home/ivan/TabbyAPI/config.yml`:

```yaml
model:
  model_dir: /path/to/model
  
network:
  host: 0.0.0.0
  port: 5000

auth:
  disable: true
```

**Note**: This may require deleting `api_tokens.yml` if it exists:

```bash
rm /home/ivan/TabbyAPI/api_tokens.yml
systemctl restart tabbyapi.service
```

### Option 2: Update Router Health Check with API Key

Modify `/opt/llm-router/router.py` to pass API key for TabbyAPI health checks:

```python
async def check_health(backend):
    try:
        port = {"sglang": SGLANG_PORT, "tabbyapi": TABBY_PORT, "llamacpp": LLAMACPP_PORT}[backend]
        
        # Read TabbyAPI API key
        headers = {}
        if backend == "tabbyapi":
            try:
                import yaml
                with open("/home/ivan/TabbyAPI/api_tokens.yml") as f:
                    tokens = yaml.safe_load(f)
                    headers["Authorization"] = f"Bearer {tokens['api_key']}"
            except:
                pass
        
        async with httpx.AsyncClient(timeout=5.0) as c:
            test_body = {"model": "test", "prompt": "hi", "max_tokens": 1, "stream": False}
            if backend == "llamacpp":
                r = await c.post(f"http://localhost:{port}/v1/completions", json=test_body, headers=headers)
            else:
                r = await c.post(f"http://localhost:{port}/v1/chat/completions", 
                    json={"model": "test", "messages": [{"role": "user", "content": "hi"}], "max_tokens": 1, "stream": False},
                    headers=headers)
            return r.status_code in [200, 404, 401]  # 401 means auth required but server is up
    except: return False
```

### Option 3: Use Environment Variable for API Key

1. Store API key in systemd service:

```ini
[Service]
Environment="TABBY_API_KEY=your-api-key-here"
```

2. Read in router:

```python
TABBY_API_KEY = os.getenv("TABBY_API_KEY", "")
```

## Recommended Approach

**For local development**: Use Option 1 (disable auth)  
**For production**: Use Option 2 or 3 with proper key management

## Testing

After applying fix:

```bash
# Test TabbyAPI directly
curl -X POST http://localhost:5000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "test",
    "messages": [{"role": "user", "content": "hi"}],
    "max_tokens": 1
  }'

# Should return error about model not found (not auth error)
```

## Status

- **Priority**: Medium
- **Effort**: 15-30 minutes
- **Blocking**: TabbyAPI (EXL2 models) functionality

---
**Version**: 4.0.0  
**Last Updated**: January 26, 2025
