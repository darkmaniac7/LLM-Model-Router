# LLM Documentation - Blackwell GB200 Setup

Welcome to your Blackwell GB200 LLM inference setup documentation.

## 📚 Documentation Index

### 1. [BLACKWELL_SETUP_COMPLETE.md](BLACKWELL_SETUP_COMPLETE.md)
**Comprehensive setup guide** - Read this first!
- Complete system overview
- Architecture diagram
- All 6 available models
- Services & auto-start configuration
- Router features v3.1.1
- Troubleshooting guide
- File locations

### 2. [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
**Command cheat sheet** - Daily operations
- Most common commands
- Quick status checks
- Restart procedures
- Log viewing
- Performance checks
- One-liner troubleshooting

### 3. [BLACKWELL_IMPROVEMENTS.md](BLACKWELL_IMPROVEMENTS.md)
**Performance analysis** - Why ~22 tok/s?
- Current performance explained
- Blackwell sm_120 kernel maturity
- Comparison with 4x3090 setup
- Tracking updates
- Future expectations
- Timeline for improvements

## 🚀 Quick Start

### Check Everything is Running
```bash
curl http://localhost:8002/health | jq .
```

### List Available Models
```bash
curl http://localhost:8002/v1/models | jq '.data[].id'
```

### Test a Request
```bash
curl -X POST http://localhost:8002/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral-large-2411-awq",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 50
  }' | jq -r '.choices[0].message.content'
```

## 📊 Current Status

- **Models Available:** 6 (5 AWQ + 1 EXL2)
- **Router Version:** 3.1.1
- **Performance:** ~22-25 tok/s
- **Auto-start:** Configured via systemd
- **Features:** Streaming status, inline tok/s metrics

## 🔗 Quick Links

### Services
- OpenWebUI: http://localhost:3000
- Router API: http://localhost:8002
- SGLang Backend: http://localhost:30000
- TabbyAPI Backend: http://localhost:5000

### Logs
```bash
# Router
tail -f /tmp/router_blackwell.log

# SGLang
journalctl -u sglang.service -f

# TabbyAPI
journalctl -u tabbyapi.service -f
```

### Key Directories
```
/home/ivan/sglang/          # Scripts & router
/home/ivan/models/          # Model weights
/home/ivan/llm_docs/        # This documentation
/etc/systemd/system/        # Service configs
```

## 💡 Need Help?

1. Check [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for commands
2. Read [BLACKWELL_SETUP_COMPLETE.md](BLACKWELL_SETUP_COMPLETE.md) troubleshooting section
3. View live logs with `journalctl -u sglang.service -f`
4. Restart everything: See Quick Reference

## 📝 Notes

- All models show tok/s at end of responses
- Model switching takes 30-60 seconds
- Router shows progress during loading
- Current 22-25 tok/s is due to sm_120 kernel limitations
- Performance will improve significantly as kernels mature

---

**Last Updated:** October 25, 2025
