#!/bin/bash
# DeepSeek-R1-Distill-Llama-70B AWQ - Blackwell Edition

source /home/ivan/sglang/sglang-env/bin/activate

export CUDA_VISIBLE_DEVICES=0

python -m sglang.launch_server --sleep-on-idle \
    --model-path /home/ivan/models/DeepSeek-R1-Distill-Llama-70B-AWQ \
    --host 0.0.0.0 \
    --port 30000 \
    --tp 1 \
    --attention-backend triton \
    --served-model-name deepseek-r1-distill-70b-awq \
    --mem-fraction-static 0.88 \
    --chunked-prefill-size 8192 \
    --log-level info \
    --log-requests
