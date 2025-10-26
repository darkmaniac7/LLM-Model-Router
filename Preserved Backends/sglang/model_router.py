#!/usr/bin/env python3
"""
SGLang Multi-Model Auto-Switching Router for OpenWebUI
ALL models unified on port 8001
"""

from fastapi import FastAPI, Request, HTTPException
import httpx
import subprocess
import asyncio
import logging
import uvicorn

logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

app = FastAPI(title="SGLang Model Router", version="2.1.0")

# ALL models use port 8001
SGLANG_URL = "http://localhost:8001"

MODELS = {
    "mistral-large-2411-awq": "/home/ivan/sglang/start_sglang_mistral_tp4_compiled.sh",
    "llama-3.3-70b-awq": "/home/ivan/sglang/start_sglang_llama33_tp4_compiled.sh",
    "deepseek-r1-distill-70b-awq": "/home/ivan/sglang/start_sglang_deepseek_tp4_compiled.sh",
    "glm-4.5-air-awq": "/home/ivan/sglang/start_sglang_glm_tp4_compiled.sh",
    "magnum-v4-123b-awq": "/home/ivan/sglang/start_sglang_magnum.sh",
}

SYSTEMD_SERVICE_PATH = "/etc/systemd/system/sglang.service"
MODEL_LOAD_TIMEOUT = 300
HEALTH_CHECK_INTERVAL = 5

current_model = None
switching_lock = asyncio.Lock()

def get_current_model() -> str:
    try:
        with open(SYSTEMD_SERVICE_PATH, "r") as f:
            content = f.read()
            for model_id, script_path in MODELS.items():
                if script_path in content:
                    return model_id
    except:
        pass
    return list(MODELS.keys())[0]

async def wait_for_sglang_ready() -> bool:
    start_time = asyncio.get_event_loop().time()
    while (asyncio.get_event_loop().time() - start_time) < MODEL_LOAD_TIMEOUT:
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{SGLANG_URL}/get_model_info", timeout=2.0)
                if response.status_code == 200:
                    logger.info("✓ Model ready!")
                    return True
        except:
            pass
        elapsed = int(asyncio.get_event_loop().time() - start_time)
        if elapsed % 10 == 0:
            logger.info(f"  Waiting... ({elapsed}s)")
        await asyncio.sleep(HEALTH_CHECK_INTERVAL)
    logger.error(f"✗ Timeout after {MODEL_LOAD_TIMEOUT}s")
    return False

async def switch_model(model_id: str) -> bool:
    global current_model
    if model_id not in MODELS:
        return False
    
    script_path = MODELS[model_id]
    logger.info("="*60)
    logger.info(f"SWITCHING TO: {model_id}")
    logger.info("="*60)
    
    try:
        subprocess.run(
            ["sudo", "sed", "-i", f"s|ExecStart=.*|ExecStart={script_path}|", SYSTEMD_SERVICE_PATH],
            capture_output=True, check=True
        )
        subprocess.run(["sudo", "systemctl", "daemon-reload"], capture_output=True, check=True)
        subprocess.run(["sudo", "systemctl", "restart", "sglang.service"], capture_output=True, check=True)
        
        if await wait_for_sglang_ready():
            current_model = model_id
            logger.info(f"✓ SUCCESS! Now running: {model_id}")
            return True
        return False
    except Exception as e:
        logger.error(f"Switch failed: {e}")
        return False

@app.get("/v1/models")
async def list_models():
    models = []
    for model_id in MODELS.keys():
        models.append({
            "id": model_id,
            "object": "model",
            "created": 1234567890,
            "owned_by": "local",
            "permission": [],
            "root": model_id,
            "parent": None
        })
    return {"object": "list", "data": models}

@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    global current_model
    body = await request.json()
    requested_model = body.get("model", list(MODELS.keys())[0])
    
    logger.info(f"→ Request for: {requested_model}")
    
    if requested_model not in MODELS:
        raise HTTPException(status_code=400, detail=f"Unknown model: {requested_model}")
    
    async with switching_lock:
        if current_model is None:
            current_model = get_current_model()
        
        if current_model != requested_model:
            logger.info(f"  Switch needed: {current_model} → {requested_model}")
            if not await switch_model(requested_model):
                raise HTTPException(status_code=503, detail=f"Failed to switch to {requested_model}")
        else:
            logger.info(f"  Already active: {requested_model}")
    
    messages = body.get("messages", [])
    prompt = ""
    for msg in messages:
        role = msg.get("role", "")
        content = msg.get("content", "")
        if role == "system":
            prompt += f"{content}\n\n"
        elif role == "user":
            prompt += f"User: {content}\n\n"
        elif role == "assistant":
            prompt += f"Assistant: {content}\n\n"
    
    if not prompt.endswith("Assistant:"):
        prompt += "Assistant:"
    
    sglang_request = {
        "text": prompt,
        "sampling_params": {
            "temperature": body.get("temperature", 0.7),
            "top_p": body.get("top_p", 1.0),
            "max_new_tokens": body.get("max_tokens", 2048),
        }
    }
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(f"{SGLANG_URL}/generate", json=sglang_request, timeout=300.0)
            response.raise_for_status()
            result = response.json()
        
        return {
            "id": "chatcmpl-" + result["meta_info"]["id"],
            "object": "chat.completion",
            "created": 1234567890,
            "model": requested_model,
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": result["text"].strip()
                },
                "finish_reason": "stop"
            }],
            "usage": {
                "prompt_tokens": result["meta_info"]["prompt_tokens"],
                "completion_tokens": result["meta_info"]["completion_tokens"],
                "total_tokens": result["meta_info"]["prompt_tokens"] + result["meta_info"]["completion_tokens"]
            }
        }
    except Exception as e:
        logger.error(f"Error: {e}")
        raise HTTPException(status_code=502, detail=str(e))

@app.get("/health")
async def health():
    current = get_current_model()
    sglang_healthy = False
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{SGLANG_URL}/get_model_info", timeout=2.0)
            sglang_healthy = (response.status_code == 200)
    except:
        pass
    
    return {
        "status": "healthy",
        "current_model": current,
        "sglang_responding": sglang_healthy,
        "available_models": list(MODELS.keys()),
        "unified_endpoint": SGLANG_URL
    }

@app.get("/")
async def root():
    return {
        "name": "SGLang Multi-Model Router",
        "version": "2.1.0",
        "current_model": get_current_model(),
        "models": list(MODELS.keys())
    }

if __name__ == "__main__":
    logger.info("="*70)
    logger.info("  SGLang Router v2.1 - Unified Port 8001")
    logger.info("="*70)
    logger.info(f"  Models: {list(MODELS.keys())}")
    logger.info("="*70)
    current_model = get_current_model()
    logger.info(f"  Current: {current_model}")
    logger.info("="*70)
    uvicorn.run(app, host="0.0.0.0", port=8002, log_level="info")
