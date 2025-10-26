#!/usr/bin/env python3
"""
Multi-Backend LLM Router v3.3.0
Simplified - No systemd required, just model paths
"""
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse
import httpx, subprocess, asyncio, logging, uvicorn, json, time, os

logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(levelname)s: %(message)s')
logger = logging.getLogger(__name__)
app = FastAPI(title="Multi-Backend LLM Router", version="3.3.0")

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

current_model, current_process, switching_lock = None, None, asyncio.Lock()

def create_sse(data): return f"data: {json.dumps(data)}\n\n"

async def check_health(backend):
    try:
        port = {"sglang": SGLANG_PORT, "tabbyapi": TABBY_PORT, "llamacpp": LLAMACPP_PORT}[backend]
        async with httpx.AsyncClient(timeout=2.0) as c:
            return (await c.get(f"http://localhost:{port}/v1/models")).status_code == 200
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
    global current_process
    subprocess.run(["pkill", "-9", "llama-server"], capture_output=True)
    subprocess.run(["pkill", "-9", "-f", "sglang"], capture_output=True)
    if current_process:
        try: current_process.kill()
        except: pass
    await asyncio.sleep(2)
    
    backend, path = model_info["backend"], model_info["model_path"]
    if backend == "sglang":
        cmd = f"export PATH=/usr/local/cuda/bin:$PATH && cd $HOME/sglang && source sglang-env/bin/activate && python -m sglang.launch_server --model-path {path} --port {SGLANG_PORT} --host 0.0.0.0"
        current_process = subprocess.Popen(cmd, shell=True, executable="/bin/bash")
        async for s in wait_ready("sglang"): yield s
    elif backend == "llamacpp":
        cmd = f"$HOME/llama.cpp/build/bin/llama-server -m {path} -ngl 999 --port {LLAMACPP_PORT} --host 0.0.0.0 -c 4096"
        current_process = subprocess.Popen(cmd, shell=True)
        async for s in wait_ready("llamacpp"): yield s
    else:
        yield {"status": "error", "message": "TabbyAPI not yet supported"}

@app.get("/v1/models")
async def list_models():
    return {"object": "list", "data": [{"id": k, "object": "model", "created": 1234567890, "owned_by": "local"} for k in MODELS.keys()]}

@app.post("/v1/chat/completions")
async def chat(request: Request):
    global current_model
    body = await request.json()
    model = body.get("model")
    
    async def generate():
        async with switching_lock:
            if current_model != model:
                yield create_sse({"choices": [{"delta": {"content": f"🔄 Switching to {model}...\n"}}]})
                async for s in start_backend(MODELS[model]):
                    if s["status"] == "loading":
                        yield create_sse({"choices": [{"delta": {"content": f"⏳ {s['elapsed']}s\n"}}]})
                    elif s["status"] == "ready":
                        current_model = model
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
    return {"status": "healthy", "current_model": current_model, "models": list(MODELS.keys())}

if __name__ == "__main__":
    logger.info("="*60)
    logger.info("Multi-Backend LLM Router v3.3.0")
    logger.info(f"Models: {list(MODELS.keys())}")
    logger.info("="*60)
    uvicorn.run(app, host="0.0.0.0", port=ROUTER_PORT)
