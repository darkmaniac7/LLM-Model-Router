#!/bin/bash
# Start GLM-4.5-Air-AWQ on port 8002 using GPUs 1,2,3,4 with TP=2, PP=2
export CUDA_VISIBLE_DEVICES=1,2,3,4
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

cd /home/ivan/sglang
source sglang-env/bin/activate

python -m sglang.launch_server \
  --model-path /home/ivan/models/GLM-4.5-Air-AWQ \
  --host 0.0.0.0 \
  --port 8002 \
  --dtype float16 \
  --tp-size 2 \
  --pp-size 2 \
  --context-length 32768 \
  --served-model-name glm-4.5-air-awq \
  --mem-fraction-static 0.88 \
  --log-level info \
  --log-requests \
  --tool-call-parser glm45 \
  --reasoning-parser glm45
