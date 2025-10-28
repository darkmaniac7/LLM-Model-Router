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
import time
import json

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
            start_time = time.time()
            token_count = 0
            
            async with httpx.AsyncClient(timeout=300.0) as client:
                try:
                    async with client.stream('POST', f"{SGLANG_URL}/v1/chat/completions", json=body) as response:
                        response.raise_for_status()
                        async for chunk in response.aiter_bytes():
                            chunk_str = chunk.decode() if isinstance(chunk, bytes) else chunk
                            
                            # Count tokens from streamed content
                            if chunk_str.startswith("data: "):
                                try:
                                    data_str = chunk_str[6:].strip()
                                    if data_str and data_str != "[DONE]":
                                        chunk_data = json.loads(data_str)
                                        if "choices" in chunk_data and len(chunk_data["choices"]) > 0:
                                            delta = chunk_data["choices"][0].get("delta", {})
                                            content = delta.get("content", "")
                                            if content:
                                                token_count += max(1, len(content) // 4)
                                except:
                                    pass
                            
                            yield chunk_str.encode() if isinstance(chunk_str, str) else chunk
                except Exception as e:
                    logger.error(f"Streaming error: {e}")
            
            # Append performance metrics after completion
            elapsed = time.time() - start_time
            if elapsed > 0 and token_count > 0:
                tok_per_sec = token_count / elapsed
                perf_sse = f"data: {{\"choices\": [{{\"delta\": {{\"content\": \"\\n\\n⚡ {tok_per_sec:.1f} tok/s (~{token_count} tokens in {elapsed:.1f}s)\"}}, \"index\": 0}}]}}\n\n"
                yield perf_sse.encode()
                logger.info(f"Performance: {tok_per_sec:.1f} tok/s ({token_count} tokens in {elapsed:.2f}s)")
        
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
