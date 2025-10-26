#!/bin/bash
# Start Magnum-v4-123B-AWQ with torch.compile ENABLED
# CUDA graphs enabled by default
# Using GPUs 1-4 with TP=4

export CUDA_VISIBLE_DEVICES=1,2,3,4
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

cd /home/ivan/sglang
source sglang-env/bin/activate

python -m sglang.launch_server \
  --model-path /home/ivan/models/Magnum-v4-123B-AWQ \
  --host 0.0.0.0 \
  --port 8001 \
  --dtype float16 \
  --tp-size 4 \
  --context-length 16384 \
  --served-model-name magnum-v4-123b-awq \
  --mem-fraction-static 0.78 \
  --log-level info \
  --log-requests \
  --enable-torch-compile
