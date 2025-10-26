#!/bin/bash
# Mistral-Large AWQ - Blackwell Optimized for Max Performance

source /home/ivan/sglang/sglang-env/bin/activate

export CUDA_VISIBLE_DEVICES=0

# Performance optimizations
export CUDA_LAUNCH_BLOCKING=0
export CUDA_DEVICE_MAX_CONNECTIONS=32
export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True,max_split_size_mb:512"
export TRITON_CACHE_DIR=/tmp/triton_cache
export TRITON_KERNEL_CACHE_SIZE=10000

python -m sglang.launch_server \
    --model-path /home/ivan/models/Mistral-Large-Instruct-2411-AWQ \
    --host 0.0.0.0 \
    --port 30000 \
    --tp 1 \
    --attention-backend triton \
    --served-model-name mistral-large-2411-awq \
    --mem-fraction-static 0.92 \
    --chunked-prefill-size 16384 \
    --max-running-requests 8 \
    --schedule-policy fcfs \
    --log-level info \
    --log-requests
