#!/bin/bash
# Llama 3.3 70B Instruct Abliterated AWQ - Blackwell Edition

source /home/ivan/sglang/sglang-env/bin/activate

export CUDA_VISIBLE_DEVICES=0

python -m sglang.launch_server --sleep-on-idle \
    --model-path /home/ivan/models/llama3.3-70B-instruct-abliterated-awq \
    --host 0.0.0.0 \
    --port 30000 \
    --tp 1 \
    --attention-backend triton \
    --served-model-name llama-3.3-70b-awq \
    --mem-fraction-static 0.88 \
    --chunked-prefill-size 8192 \
    --log-level info \
    --log-requests
