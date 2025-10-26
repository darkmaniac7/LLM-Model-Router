#!/bin/bash
# SGLang server startup script for Mistral-Large-Instruct-2411-AWQ with TP=4

source /home/ivan/sglang/sglang-env/bin/activate

/home/ivan/sglang/sglang-env/bin/python -m sglang.launch_server \
    --model-path /home/ivan/models/Mistral-Large-Instruct-2411-AWQ \
    --host 0.0.0.0 \
    --port 8001 \
    --tp 4 \
    --context-length 24576 \
    --quantization awq_marlin \
    --served-model-name mistral-large-2411-awq \
    --mem-fraction-static 0.80 \
    --log-level info \
    --log-requests
