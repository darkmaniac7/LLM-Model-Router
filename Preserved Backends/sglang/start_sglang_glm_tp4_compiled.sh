#!/bin/bash
# SGLang server with torch.compile ENABLED for maximum performance
# GLM-4.5-Air-AWQ-FP16Mix (MoE model with mixed quantization)
# CUDA graphs enabled by default
# Using GPUs 1-4 (NVLink connected, includes FTW3 Ultras on 1&2!)

source /home/ivan/sglang/sglang-env/bin/activate

export CUDA_VISIBLE_DEVICES=1,2,3,4

/home/ivan/sglang/sglang-env/bin/python -m sglang.launch_server \
    --model-path /home/ivan/models/GLM-4.5-Air-AWQ-FP16Mix \
    --host 0.0.0.0 \
    --port 8001 \
    --tp 4 \
    --ep-size 4 \
    --context-length 24576 \
    --served-model-name glm-4.5-air-awq \
    --mem-fraction-static 0.80 \
    --log-level info \
    --log-requests \
    --enable-torch-compile \
    --sleep-on-idle
