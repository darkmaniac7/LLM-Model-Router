#!/bin/bash
cd /home/ivan/llama.cpp/build
exec ./bin/llama-server \
    -m /home/ivan/models/gguf/TheDrummer_Behemoth-R1-123B-v2-IQ4_NL/TheDrummer_Behemoth-R1-123B-v2-IQ4_NL/TheDrummer_Behemoth-R1-123B-v2-IQ4_NL-00001-of-00002.gguf \
    -ngl 999 \
    --port 8085 \
    --host 0.0.0.0 \
    -c 4096 \
    --parallel 1
