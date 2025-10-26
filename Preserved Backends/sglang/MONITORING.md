# SGLang Token/s Monitoring Guide

## Quick Methods to See Tok/s

### 1. **Real-time Log Monitoring** (EASIEST)
```bash
tail -f /home/ivan/sglang/sglang.log | grep --line-buffered "tok/s"
```
This shows tok/s for each request as it completes. With `--log-requests` enabled, you'll see output like:
```
[2025-10-13 03:45:12] Request 123: prompt_tokens=50, completion_tokens=100, total_time=5.2s, throughput=19.23 tok/s
```

### 2. **Metrics Endpoint** (AGGREGATED STATS)
```bash
curl -s http://localhost:8001/metrics
```
Returns Prometheus-style metrics including:
- `sglang_request_throughput` - tokens/second across all requests
- `sglang_time_to_first_token` - TTFT latency
- `sglang_time_per_output_token` - Generation speed per token

### 3. **Live Stats Dashboard** (BEST FOR MONITORING)
```bash
watch -n 1 'curl -s http://localhost:8001/metrics | grep -E "(throughput|latency|tok)"'
```
Updates every second with current performance metrics.

### 4. **Test Request with Timing**
```bash
curl -w "\nTime: %{time_total}s\n" http://localhost:8001/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral-large-2411-awq",
    "prompt": "Count from 1 to 100:",
    "max_tokens": 200,
    "stream": false
  }' | jq '.usage'
```
Shows total tokens and time, calculate: `completion_tokens / time_total`

### 5. **In Open-WebUI**
When you generate text in Open-WebUI, look at the bottom of the response:
- It shows tokens/second in the UI
- Typically displays as: "Generated in 5.2s (19 tok/s)"

## Helper Scripts

### Interactive Monitor
```bash
/home/ivan/sglang/monitor_tokps.sh
```

### Simple Live Monitor
```bash
tail -f /home/ivan/sglang/sglang.log | grep --line-buffered -i "throughput\|tok/s\|tokens per second"
```

## Expected Performance (TP=4 on RTX 3090s)

- **Prefill (prompt processing)**: Very fast, ~1000-2000 tok/s
- **Decode (generation)**: 18-25 tok/s per request
- **Time to First Token (TTFT)**: 100-300ms
- **Batch throughput**: Increases with concurrent requests

## Notes

- The `--log-requests` flag enables per-request logging with tok/s
- Metrics endpoint updates continuously
- SGLang typically shows better tok/s than vLLM for single requests
- Stream mode gives perception of faster response (shows tokens as generated)
