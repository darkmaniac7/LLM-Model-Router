#!/bin/bash
# Start GLM-4.5-Air-AWQ with torch.compile ENABLED
# This is the proper AWQ quantized version (not the 4bit one)
# MoE model with 128 routed experts, uses 8 experts per token
# CUDA graphs enabled by default
# Using GPUs 1-4 with TP=2, PP=2 for best memory distribution

export CUDA_VISIBLE_DEVICES=1,2,3,4
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

cd /home/ivan/sglang
source sglang-env/bin/activate

python -m sglang.launch_server \
  --model-path /home/ivan/models/GLM-4.5-Air-AWQ \
  --host 0.0.0.0 \
  --port 8001 \
  --dtype bfloat16 \
  --tp-size 2 \
  --pp-size 2 \
  --context-length 32768 \
  --served-model-name glm-4.5-air-awq \
  --mem-fraction-static 0.88 \
  --log-level info \
  --log-requests \
  --enable-torch-compile
