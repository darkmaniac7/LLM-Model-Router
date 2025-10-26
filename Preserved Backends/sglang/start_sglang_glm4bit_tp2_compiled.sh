#!/bin/bash
source /home/ivan/sglang/sglang-env/bin/activate
export CUDA_VISIBLE_DEVICES=1,2,3,4
/home/ivan/sglang/sglang-env/bin/python -m sglang.launch_server \
    --model-path /home/ivan/models/GLM-4.5-Air-AWQ-4bit \
    --host 0.0.0.0 \
    --port 8001 \
    --tensor-parallel-size 2 \
    --pipeline-parallel-size 2 \
    --context-length 24576 \
    --served-model-name glm-4.5-air-awq-4bit \
    --mem-fraction-static 0.80 \
    --log-level info \
    --log-requests \
    --enable-torch-compile \
    --sleep-on-idle
