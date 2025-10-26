#!/bin/bash
echo "=== torch.compile Progress Monitor ==="
echo ""
echo "Current time: $(date)"
echo ""

# Show recent compilation activity
echo "Recent activity:"
tail -20 /home/ivan/sglang/sglang.log | grep -E "(Captur|batch|compile)" | tail -5
echo ""

# Check if server is responding
if curl -s http://localhost:8001/v1/models > /dev/null 2>&1; then
    echo "✅ SERVER IS READY!"
    echo ""
    curl -s http://localhost:8001/v1/models | jq -r '.data[0].id'
    echo ""
    echo "Ready to test! Run:"
    echo "  /home/ivan/sglang/test_tokps.sh"
else
    echo "⏳ Still compiling..."
    echo ""
    echo "GPU status:"
    nvidia-smi --query-gpu=index,utilization.gpu,temperature.gpu --format=csv,noheader
fi

echo ""
echo "Run this script again to check: ./monitor_compile.sh"
