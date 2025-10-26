#!/bin/bash
# SGLang server with torch.compile ENABLED for maximum performance
# DeepSeek-R1-Distill-Llama-70B AWQ
# CUDA graphs enabled by default
# Using GPUs 1-4 (NVLink connected, includes FTW3 Ultras on 1&2!)

source /home/ivan/sglang/sglang-env/bin/activate

export CUDA_VISIBLE_DEVICES=1,2,3,4

/home/ivan/sglang/sglang-env/bin/python -m sglang.launch_server \
    --model-path /home/ivan/models/DeepSeek-R1-Distill-Llama-70B-AWQ \
    --host 0.0.0.0 \
    --port 8001 \
    --tp 4 \
    --context-length 24576 \
    --quantization awq_marlin \
    --served-model-name deepseek-r1-distill-70b-awq \
    --mem-fraction-static 0.80 \
    --log-level info \
    --log-requests \
    --enable-torch-compile \
    --sleep-on-idle
