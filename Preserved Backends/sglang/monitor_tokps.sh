#!/bin/bash
# Monitor SGLang tokens per second in real-time

echo "=== SGLang Performance Monitor ==="
echo ""
echo "Choose monitoring method:"
echo "1. Watch server logs (shows tok/s per request)"
echo "2. Query metrics endpoint (shows aggregate stats)"
echo "3. Test request with timing (manual benchmark)"
echo ""
read -p "Enter choice (1-3): " choice

case $choice in
  1)
    echo "Monitoring logs... (Ctrl+C to stop)"
    tail -f /home/ivan/sglang/sglang.log | grep --line-buffered -E "(tok/s|tokens/s|throughput)"
    ;;
  2)
    echo "Querying metrics endpoint..."
    curl -s http://localhost:8001/metrics | grep -E "(throughput|tok|latency|request)"
    ;;
  3)
    echo "Running test request..."
    time curl -s http://localhost:8001/v1/completions \
      -H "Content-Type: application/json" \
      -d '{
        "model": "mistral-large-2411-awq",
        "prompt": "Write a short poem about AI:",
        "max_tokens": 100,
        "stream": false
      }' | jq -r '.usage'
    ;;
  *)
    echo "Invalid choice"
    ;;
esac
