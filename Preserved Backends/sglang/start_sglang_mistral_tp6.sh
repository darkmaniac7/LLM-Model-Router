#!/bin/bash
# SGLang TP=6 for Mistral-Large-2411-AWQ on 6x RTX 3090

export CUDA_VISIBLE_DEVICES=0,1,2,3,4,5
export NCCL_P2P_DISABLE=0
export NCCL_IB_DISABLE=1
export NCCL_P2P_LEVEL=PXB

/home/ivan/sglang/sglang-env/bin/python -m sglang.launch_server \
  --model-path /home/ivan/models/Mistral-Large-Instruct-2411-AWQ \
  --host 0.0.0.0 \
  --port 8001 \
  --tp 6 \
  --context-length 32768 \
  --quantization awq \
  --served-model-name mistral-large-2411-awq \
  --enable-torch-compile \
  --mem-fraction-static 0.88
