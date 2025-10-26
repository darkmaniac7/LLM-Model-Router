#!/bin/bash
# Mistral-Large AWQ with FlashAttention-4 for prefill

source /home/ivan/sglang/sglang-env/bin/activate

export CUDA_VISIBLE_DEVICES=0

python -m sglang.launch_server \
    --model-path /home/ivan/models/Mistral-Large-Instruct-2411-AWQ \
    --host 0.0.0.0 \
    --port 30000 \
    --tp 1 \
    --prefill-attention-backend fa4 \
    --decode-attention-backend triton \
    --served-model-name mistral-large-2411-awq \
    --mem-fraction-static 0.75 \
    --chunked-prefill-size 8192 \
    --log-level info \
    --log-requests
