#!/bin/bash
# Example startup script for llama.cpp with GGUF model
# Update paths below to match your installation

# Set your paths here
LLAMACPP_DIR="${LLAMACPP_DIR:-$HOME/llama.cpp}"
MODEL_PATH="${MODEL_PATH:-$HOME/models/gguf/YourModel.gguf}"

cd "$LLAMACPP_DIR/build"
exec ./bin/llama-server \
    -m "$MODEL_PATH" \
    -ngl 999 \
    --port 8085 \
    --host 0.0.0.0 \
    -c 4096 \
    --parallel 1
