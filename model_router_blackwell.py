#!/usr/bin/env python3
"""
SGLang Model Router for Blackwell - Port 8002
Routes OpenWebUI requests (port 8002) to SGLang backend (port 30000)
"""

from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse, JSONResponse
import httpx
import uvicorn
import logging

logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

app = FastAPI(title="SGLang Router - Blackwell", version="4.2.0")

SGLANG_URL = "http://localhost:30000"

@app.get("/v1/models")
async def list_models():
    return {
        "object": "list",
        "data": [{
            "id": "mistral-large-2411-awq",
            "object": "model",
            "created": 1234567890,
            "owned_by": "local-blackwell"
        }]
    }

@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    body = await request.json()
    stream = body.get("stream", False)
    
    logger.info(f"→ Chat request (stream={stream})")
    
    if stream:
        async def generate():
            async with httpx.AsyncClient(timeout=300.0) as client:
                try:
                    async with client.stream('POST', f"{SGLANG_URL}/v1/chat/completions", json=body) as response:
                        response.raise_for_status()
                        async for chunk in response.aiter_bytes():
                            yield chunk
                except Exception as e:
                    logger.error(f"Streaming error: {e}")
        
        return StreamingResponse(
            generate(), 
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no"
            }
        )
    else:
        async with httpx.AsyncClient(timeout=300.0) as client:
            response = await client.post(f"{SGLANG_URL}/v1/chat/completions", json=body)
            return JSONResponse(content=response.json())

@app.get("/health")
async def health():
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            response = await client.get(f"{SGLANG_URL}/get_model_info")
            sglang_healthy = (response.status_code == 200)
    except:
        sglang_healthy = False
    
    return {
        "status": "healthy",
        "router_version": "4.2.0-blackwell",
        "sglang_responding": sglang_healthy,
        "backend_url": SGLANG_URL
    }

if __name__ == "__main__":
    logger.info("="*60)
    logger.info("SGLang Router v4.2.0 - Blackwell Edition")
    logger.info(f"Backend: {SGLANG_URL}")
    logger.info("Router: http://0.0.0.0:8002")
    logger.info("="*60)
    uvicorn.run(app, host="0.0.0.0", port=8002, log_level="info")
