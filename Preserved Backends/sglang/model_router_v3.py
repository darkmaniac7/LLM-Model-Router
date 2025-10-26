#!/usr/bin/env python3
"""
SGLang Multi-Model Auto-Switching Router for OpenWebUI v3.0
ALL models unified on port 8001
Features:
- Streaming loading messages to prevent OpenWebUI timeout
- Better error handling and status updates
- OpenAI-compatible API endpoints
- Fixed cumulative streaming from SGLang
"""

from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import StreamingResponse
import httpx
import subprocess
import asyncio
import logging
import uvicorn
import json
import time

logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

app = FastAPI(title="SGLang Model Router", version="3.0.1")

# ALL models use port 8001
SGLANG_URL = "http://localhost:8001"

MODELS = {
    "mistral-large-2411-awq": "/home/ivan/sglang/start_sglang_mistral_tp4_compiled.sh",
    "llama-3.3-70b-awq": "/home/ivan/sglang/start_sglang_llama33_tp4_compiled.sh",
    "deepseek-r1-distill-70b-awq": "/home/ivan/sglang/start_sglang_deepseek_tp4_compiled.sh",
    "glm-4.5-air-awq": "/home/ivan/sglang/start_sglang_glm_tp4_compiled.sh",
    "magnum-v4-123b-awq": "/home/ivan/sglang/start_sglang_magnum.sh",
    "kat-dev-awq-8bit": "/home/ivan/sglang/start_sglang_katdev.sh",
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

async def wait_for_sglang_ready_streaming():
    """
    Generator that yields status messages while waiting for model to load.
    This allows us to send periodic updates to prevent client timeout.
    """
    start_time = time.time()
    last_message_time = start_time
    
    while (time.time() - start_time) < MODEL_LOAD_TIMEOUT:
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{SGLANG_URL}/get_model_info", timeout=2.0)
                if response.status_code == 200:
                    elapsed = int(time.time() - start_time)
                    logger.info(f"✓ Model ready after {elapsed}s!")
                    yield {"status": "ready", "elapsed": elapsed}
                    return
        except:
            pass
        
        elapsed = int(time.time() - start_time)
        
        # Send update every 10 seconds
        if time.time() - last_message_time >= 10:
            logger.info(f"  Loading... ({elapsed}s / {MODEL_LOAD_TIMEOUT}s)")
            yield {"status": "loading", "elapsed": elapsed, "timeout": MODEL_LOAD_TIMEOUT}
            last_message_time = time.time()
        
        await asyncio.sleep(2)
    
    logger.error(f"✗ Timeout after {MODEL_LOAD_TIMEOUT}s")
    yield {"status": "timeout", "elapsed": MODEL_LOAD_TIMEOUT}

async def wait_for_sglang_ready() -> bool:
    """Simple non-streaming version for health checks"""
    start_time = time.time()
    while (time.time() - start_time) < MODEL_LOAD_TIMEOUT:
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{SGLANG_URL}/get_model_info", timeout=2.0)
                if response.status_code == 200:
                    logger.info("✓ Model ready!")
                    return True
        except:
            pass
        elapsed = int(time.time() - start_time)
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

def create_sse_message(data: dict) -> str:
    """Create a Server-Sent Event message"""
    return f"data: {json.dumps(data)}\n\n"

async def streaming_chat_with_model_switch(requested_model: str, body: dict):
    """
    Generator that handles model switching with streaming status updates,
    then streams the actual chat response.
    Fixed to handle SGLang's cumulative streaming properly.
    """
    global current_model
    
    # Check if we need to switch models
    async with switching_lock:
        if current_model is None:
            current_model = get_current_model()
        
        if current_model != requested_model:
            logger.info(f"  Switch needed: {current_model} → {requested_model}")
            
            # Send initial switching message
            yield create_sse_message({
                "choices": [{
                    "delta": {"role": "assistant", "content": f"🔄 Switching to {requested_model}...\n\n"},
                    "index": 0
                }]
            })
            
            # Start the switch
            if requested_model not in MODELS:
                yield create_sse_message({
                    "choices": [{
                        "delta": {"content": f"❌ Error: Unknown model {requested_model}"},
                        "index": 0,
                        "finish_reason": "error"
                    }]
                })
                return
            
            script_path = MODELS[requested_model]
            try:
                subprocess.run(
                    ["sudo", "sed", "-i", f"s|ExecStart=.*|ExecStart={script_path}|", SYSTEMD_SERVICE_PATH],
                    capture_output=True, check=True
                )
                subprocess.run(["sudo", "systemctl", "daemon-reload"], capture_output=True, check=True)
                subprocess.run(["sudo", "systemctl", "restart", "sglang.service"], capture_output=True, check=True)
            except Exception as e:
                logger.error(f"Switch failed: {e}")
                yield create_sse_message({
                    "choices": [{
                        "delta": {"content": f"\n\n❌ Failed to switch model: {str(e)}"},
                        "index": 0,
                        "finish_reason": "error"
                    }]
                })
                return
            
            # Stream loading status updates
            async for status in wait_for_sglang_ready_streaming():
                if status["status"] == "loading":
                    # Send periodic updates
                    yield create_sse_message({
                        "choices": [{
                            "delta": {"content": f"⏳ Loading model... {status['elapsed']}s / {status['timeout']}s\n"},
                            "index": 0
                        }]
                    })
                elif status["status"] == "ready":
                    current_model = requested_model
                    logger.info(f"✓ SUCCESS! Now running: {requested_model}")
                    yield create_sse_message({
                        "choices": [{
                            "delta": {"content": f"✅ Model ready! ({status['elapsed']}s)\n\n"},
                            "index": 0
                        }]
                    })
                    break
                elif status["status"] == "timeout":
                    yield create_sse_message({
                        "choices": [{
                            "delta": {"content": "\n\n❌ Model loading timed out. Please try again or check the logs."},
                            "index": 0,
                            "finish_reason": "error"
                        }]
                    })
                    return
        else:
            logger.info(f"  Already active: {requested_model}")
    
    # Now forward the actual chat request to SGLang
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
        },
        "stream": True
    }
    
    try:
        # Track previous text to extract only new tokens
        previous_text = ""
        
        async with httpx.AsyncClient() as client:
            async with client.stream('POST', f"{SGLANG_URL}/generate", json=sglang_request, timeout=300.0) as response:
                response.raise_for_status()
                async for line in response.aiter_lines():
                    if line.startswith("data: "):
                        data_str = line[6:]
                        if data_str.strip() == "[DONE]":
                            yield create_sse_message({
                                "choices": [{
                                    "delta": {},
                                    "index": 0,
                                    "finish_reason": "stop"
                                }]
                            })
                            break
                        try:
                            data = json.loads(data_str)
                            # SGLang returns cumulative text, extract only new part
                            current_text = data.get("text", "")
                            if current_text.startswith(previous_text):
                                new_text = current_text[len(previous_text):]
                                if new_text:
                                    yield create_sse_message({
                                        "choices": [{
                                            "delta": {"content": new_text},
                                            "index": 0
                                        }]
                                    })
                                    previous_text = current_text
                        except json.JSONDecodeError:
                            continue
    except Exception as e:
        logger.error(f"Error during chat: {e}")
        yield create_sse_message({
            "choices": [{
                "delta": {"content": f"\n\n❌ Error: {str(e)}"},
                "index": 0,
                "finish_reason": "error"
            }]
        })

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
    body = await request.json()
    requested_model = body.get("model", list(MODELS.keys())[0])
    stream = body.get("stream", False)
    
    logger.info(f"→ Request for: {requested_model} (stream={stream})")
    
    if stream:
        # Return streaming response with model switching status updates
        return StreamingResponse(
            streaming_chat_with_model_switch(requested_model, body),
            media_type="text/event-stream"
        )
    else:
        # Non-streaming fallback (simpler, no loading messages)
        global current_model
        
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
                "created": int(time.time()),
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
        "router_version": "3.0.1",
        "current_model": current,
        "sglang_responding": sglang_healthy,
        "available_models": list(MODELS.keys()),
        "unified_endpoint": SGLANG_URL,
        "features": ["streaming_loading_messages", "torch_compile", "cuda_graphs", "fixed_cumulative_streaming"]
    }

if __name__ == "__main__":
    logger.info("="*60)
    logger.info("SGLang Model Router v3.0.1 - Starting")
    logger.info(f"Available models: {list(MODELS.keys())}")
    logger.info(f"Backend URL: {SGLANG_URL}")
    logger.info("="*60)
    uvicorn.run(app, host="0.0.0.0", port=8002)
