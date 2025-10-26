#!/bin/bash
# vLLM OpenAI server for GLM-4.5-Air-AWQ-4bit on port 8003
# Uses GPUs 1-4 with TP=2, PP=2 (adjustable)

export CUDA_VISIBLE_DEVICES=1,2,3,4
export VLLM_WORKER_MULTIPROC_METHOD=spawn

source /home/ivan/vllm-env/bin/activate

python -m vllm.entrypoints.openai.api_server \
  --model /home/ivan/models/GLM-4.5-Air-AWQ \
  --host 0.0.0.0 \
  --port 8003 \
  --tensor-parallel-size 2 \
  --pipeline-parallel-size 2 \
  --max-model-len 32768 \
  --dtype bfloat16 \
  --enforce-eager \
  --served-model-name glm-4.5-air-awq
