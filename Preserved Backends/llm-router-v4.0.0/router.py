#!/usr/bin/env python3
"""
Multi-Backend LLM Router v4.0.0
Using systemd services for reliable backend management
"""
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse
import httpx, subprocess, asyncio, logging, uvicorn, json, time, os

logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(levelname)s: %(message)s')
logger = logging.getLogger(__name__)
app = FastAPI(title="Multi-Backend LLM Router", version="4.0.0")

CONFIG_FILE = os.getenv("ROUTER_CONFIG", "/opt/llm-router/config.json")
try:
    config = json.load(open(CONFIG_FILE))
    backends = config.get("backends", {})
    SGLANG_PORT = backends.get("sglang", {}).get("port", 30000)
    TABBY_PORT = backends.get("tabbyapi", {}).get("port", 5000)
    LLAMACPP_PORT = backends.get("llamacpp", {}).get("port", 8085)
    MODELS = config.get("models", {})
    MODEL_LOAD_TIMEOUT = config.get("model_load_timeout", 300)
    ROUTER_PORT = config.get("router_port", 8002)
    logger.info(f"Loaded {len(MODELS)} models: {list(MODELS.keys())}")
except Exception as e:
    logger.error(f"Config error: {e}")
    MODELS, ROUTER_PORT, MODEL_LOAD_TIMEOUT = {}, 8002, 300
    SGLANG_PORT, TABBY_PORT, LLAMACPP_PORT = 30000, 5000, 8085

# Global state
state = {"current_model": None}
switching_lock = asyncio.Lock()

def create_sse(data): return f"data: {json.dumps(data)}\n\n"

async def check_health(backend):
    try:
        port = {"sglang": SGLANG_PORT, "tabbyapi": TABBY_PORT, "llamacpp": LLAMACPP_PORT}[backend]
        
        # Read TabbyAPI API key if available
        headers = {}
        if backend == "tabbyapi":
            try:
                import yaml
                api_tokens_path = "/home/ivan/TabbyAPI/api_tokens.yml"
                if os.path.exists(api_tokens_path):
                    with open(api_tokens_path) as f:
                        tokens = yaml.safe_load(f)
                        if tokens and "admin_key" in tokens:
                            headers["Authorization"] = f"Bearer {tokens['admin_key']}"
            except Exception as e:
                print(f"Warning: Could not load TabbyAPI auth token: {e}")
        
        async with httpx.AsyncClient(timeout=5.0) as c:
            # Test actual inference capability, not just endpoint availability
            test_body = {"model": "test", "prompt": "hi", "max_tokens": 1, "stream": False}
            if backend == "llamacpp":
                r = await c.post(f"http://localhost:{port}/v1/completions", json=test_body, headers=headers)
            else:
                r = await c.post(f"http://localhost:{port}/v1/chat/completions", 
                    json={"model": "test", "messages": [{"role": "user", "content": "hi"}], "max_tokens": 1, "stream": False},
                    headers=headers)
            return r.status_code in [200, 404]  # 404 means server up, just wrong model name
    except: return False


async def wait_ready(backend):
    start = time.time()
    while (time.time() - start) < MODEL_LOAD_TIMEOUT:
        if await check_health(backend):
            yield {"status": "ready", "elapsed": int(time.time() - start)}
            return
        if int(time.time() - start) % 10 == 0:
            yield {"status": "loading", "elapsed": int(time.time() - start)}
        await asyncio.sleep(2)
    yield {"status": "timeout"}

async def start_backend(model_info):
    backend = model_info["backend"]
    
    # Stop all backends
    subprocess.run(["systemctl", "stop", "sglang.service"], capture_output=True)
    subprocess.run(["systemctl", "stop", "tabbyapi.service"], capture_output=True)
    subprocess.run(["systemctl", "stop", "llamacpp.service"], capture_output=True)
    subprocess.run(["pkill", "-9", "llama-server"], capture_output=True)
    await asyncio.sleep(2)
    
    # Update TabbyAPI config if needed
    if backend == "tabbyapi":
        # Extract model name from path (e.g., "exl2/Model-Name")
        model_name = model_info["model_path"]
        config_yml = f"""developer:
  backend: exllamav2
  unsafe_launch: false
logging:
  log_generation_params: false
  log_prompt: false
  log_requests: false
model:
  cache_mode: FP16
  cache_size: 32768
  chunk_size: 4096
  gpu_split_auto: true
  max_batch_size: 1
  max_seq_len: 32768
  model_dir: /home/ivan/models
  model_name: {model_name}
  tensor_parallel: false
network:
  api_servers:
  - OAI
  disable_auth: true
  host: 0.0.0.0
  port: {TABBY_PORT}
"""
        with open("/home/ivan/TabbyAPI/config.yml", "w") as f:
            f.write(config_yml)
    
    # Start the appropriate service
    service_map = {"sglang": "sglang.service", "tabbyapi": "tabbyapi.service", "llamacpp": "llamacpp.service"}
    service = service_map.get(backend)
    
    if service:
        subprocess.run(["systemctl", "start", service], capture_output=True)
        async for s in wait_ready(backend): yield s
    else:
        yield {"status": "error", "message": f"Unknown backend: {backend}"}

@app.get("/v1/models")
async def list_models():
    return {"object": "list", "data": [{"id": k, "object": "model", "created": 1234567890, "owned_by": "local"} for k in MODELS.keys()]}

@app.post("/v1/chat/completions")
async def chat(request: Request):
    body = await request.json()
    model = body.get("model")
    
    if model not in MODELS:
        return {"error": f"Model {model} not found"}
    
    async def generate():
        async with switching_lock:
            if state["current_model"] != model:
                yield create_sse({"choices": [{"delta": {"content": f"🔄 Switching to {model}...\n"}}]})
                async for s in start_backend(MODELS[model]):
                    if s["status"] == "loading":
                        yield create_sse({"choices": [{"delta": {"content": f"⏳ {s['elapsed']}s\n"}}]})
                    elif s["status"] == "ready":
                        state["current_model"] = model
                        yield create_sse({"choices": [{"delta": {"content": "✅ Ready!\n\n"}}]})
                        break
                    else:
                        yield create_sse({"choices": [{"delta": {"content": f"❌ {s.get('message','Timeout')}\n"}, "finish_reason": "error"}]})
                        return
        
        port = {"sglang": SGLANG_PORT, "tabbyapi": TABBY_PORT, "llamacpp": LLAMACPP_PORT}[MODELS[model]["backend"]]
        async with httpx.AsyncClient(timeout=300.0) as c:
            async with c.stream('POST', f"http://localhost:{port}/v1/chat/completions", json=body) as r:
                async for chunk in r.aiter_bytes():
                    yield chunk.decode() if isinstance(chunk, bytes) else chunk
    
    return StreamingResponse(generate(), media_type="text/event-stream")

@app.get("/health")
async def health():
    return {"status": "healthy", "current_model": state["current_model"], "models": list(MODELS.keys())}

if __name__ == "__main__":
    logger.info("="*60)
    logger.info("Multi-Backend LLM Router v4.0.0 - Systemd Edition")
    logger.info(f"Models: {list(MODELS.keys())}")
    logger.info("="*60)
    uvicorn.run(app, host="0.0.0.0", port=ROUTER_PORT)
