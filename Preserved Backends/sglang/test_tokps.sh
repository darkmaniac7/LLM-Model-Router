#!/bin/bash
# Test SGLang tokens per second

echo "=== Testing SGLang Performance ==="
echo "Sending request..."

START=$(date +%s.%N)

RESPONSE=$(curl -s http://localhost:8001/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral-large-2411-awq",
    "prompt": "Write a detailed explanation of quantum computing in simple terms:",
    "max_tokens": 150,
    "stream": false,
    "temperature": 0.7
  }')

END=$(date +%s.%N)

# Calculate time
TIME=$(echo "$END - $START" | bc)

# Extract tokens
PROMPT_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.prompt_tokens')
COMPLETION_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.completion_tokens')
TOTAL_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.total_tokens')

# Calculate tok/s
TOKPS=$(echo "scale=2; $COMPLETION_TOKENS / $TIME" | bc)

echo ""
echo "=== Results ==="
echo "Prompt tokens: $PROMPT_TOKENS"
echo "Completion tokens: $COMPLETION_TOKENS"
echo "Total time: ${TIME}s"
echo "Generation speed: $TOKPS tok/s"
echo ""
echo "Generated text:"
echo "$RESPONSE" | jq -r '.choices[0].text'
