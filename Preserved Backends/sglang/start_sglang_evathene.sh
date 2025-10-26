#!/bin/bash
# Start Evathene-v1.3-AWQ on port 8002 - single GPU with CPU offloading
export CUDA_VISIBLE_DEVICES=5
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

cd /home/ivan/sglang
source sglang-env/bin/activate

python -m sglang.launch_server \
  --model-path /home/ivan/models/Evathene-v1.3-AWQ \
  --host 0.0.0.0 \
  --port 8002 \
  --tp-size 1 \
  --context-length 16384 \
  --quantization awq \
  --served-model-name evathene-v1.3-awq \
  --mem-fraction-static 0.92 \
  --cpu-offload-gb 10 \
  --log-level info \
  --log-requests
