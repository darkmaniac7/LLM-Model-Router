# Changelog

## v4.0.0 (2025-01-26)

### 🎉 Major Release - All 3 Backends Working!

#### Features
- ✅ Full support for SGLang (AWQ), llama.cpp (GGUF), and TabbyAPI (EXL2)
- ✅ Systemd service management for all backends
- ✅ Dynamic TabbyAPI auth token reading from api_tokens.yml
- ✅ Intelligent health checks with actual inference validation
- ✅ Automatic model switching with proper backend lifecycle
- ✅ OpenAI-compatible API endpoints
- ✅ Streaming support for all backends

#### Router Improvements
- Router now dynamically reads TabbyAPI admin_key from api_tokens.yml
- Health checks perform actual inference tests instead of simple endpoint checks
- Config generation preserves TabbyAPI format (model_dir + model_name)
- Better error handling and timeout management
- Improved logging for debugging

#### Backend Configuration
- **SGLang**: Blackwell GPU support with TORCH_CUDA_ARCH_LIST="8.9;9.0"
- **llama.cpp**: Build with CMAKE_CUDA_ARCHITECTURES="89;90"
- **TabbyAPI**: Working venv transfer process documented

#### Documentation
- Comprehensive README with quick start
- Detailed TabbyAPI installation guide
- Configuration examples for all backends
- Systemd service templates
- Troubleshooting guide for common issues

#### Tested On
- Ubuntu 22.04
- NVIDIA RTX PRO 6000 Blackwell GPU (96GB VRAM)
- CUDA 12.6
- Python 3.12

## v3.3.0 (2025-01-24)

### Initial Release
- Basic router functionality
- SGLang and llama.cpp support
- Subprocess-based backend management

---

**Note**: v4.0.0 represents complete rewrite with systemd management and full TabbyAPI support.
