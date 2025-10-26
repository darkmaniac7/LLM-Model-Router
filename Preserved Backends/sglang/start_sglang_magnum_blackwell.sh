#!/bin/bash
# Magnum-v4-123B-AWQ - Blackwell Edition

source /home/ivan/sglang/sglang-env/bin/activate

export CUDA_VISIBLE_DEVICES=0
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

python -m sglang.launch_server --sleep-on-idle \
    --model-path /home/ivan/models/Magnum-v4-123B-AWQ \
    --host 0.0.0.0 \
    --port 30000 \
    --tp 1 \
    --attention-backend triton \
    --served-model-name magnum-v4-123b-awq \
    --mem-fraction-static 0.88 \
    --chunked-prefill-size 8192 \
    --log-level info \
    --log-requests
