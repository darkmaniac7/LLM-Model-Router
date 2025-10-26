#!/bin/bash
# Mistral-Large-Instruct-2411-AWQ on Blackwell GPU (Triton backend)

source /home/ivan/sglang/sglang-env/bin/activate

export CUDA_VISIBLE_DEVICES=0

python -m sglang.launch_server --sleep-on-idle \
    --model-path /home/ivan/models/Mistral-Large-Instruct-2411-AWQ \
    --host 0.0.0.0 \
    --port 30000 \
    --tp 1 \
    --attention-backend triton \
    --served-model-name mistral-large-2411-awq \
    --mem-fraction-static 0.88 \
    --chunked-prefill-size 8192 \
    --log-level info \
    --log-requests
