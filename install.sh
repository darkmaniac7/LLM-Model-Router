#!/bin/bash
set -e

echo "=========================================="
echo "Multi-Backend LLM Router v4.0.0 Installer"
echo "=========================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

# Detect Python
PYTHON_CMD=""
for cmd in python3.12 python3.11 python3.10 python3; do
    if command -v $cmd &> /dev/null; then
        PYTHON_CMD=$cmd
        break
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    echo "❌ Python 3.10+ not found. Please install Python first."
    exit 1
fi

PYTHON_VERSION=$($PYTHON_CMD --version | awk '{print $2}')
echo "✓ Found Python: $PYTHON_VERSION"
echo ""

# Interactive prompts
read -p "Install directory [/opt/llm-router]: " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-/opt/llm-router}

read -p "Python virtual environment path [${INSTALL_DIR}/venv]: " PYTHON_ENV
PYTHON_ENV=${PYTHON_ENV:-${INSTALL_DIR}/venv}

read -p "Router port [8002]: " ROUTER_PORT
ROUTER_PORT=${ROUTER_PORT:-8002}

read -p "Run as user [root]: " RUN_USER
RUN_USER=${RUN_USER:-root}

echo ""
echo "=== Backend Configuration ==="
echo "For each backend, provide install location or leave empty to skip"
echo ""

# SGLang
SGLANG_ENABLED=false
read -p "SGLang directory (e.g., /home/user/sglang) [skip]: " SGLANG_DIR
if [ ! -z "$SGLANG_DIR" ]; then
    if [ ! -d "$SGLANG_DIR" ]; then
        echo "⚠️  Directory not found: $SGLANG_DIR"
        read -p "Continue anyway? (y/n): " CONT
        [[ ! "$CONT" =~ ^[Yy]$ ]] && SGLANG_DIR=""
    fi
fi

if [ ! -z "$SGLANG_DIR" ]; then
    SGLANG_ENABLED=true
    read -p "SGLang venv path [${SGLANG_DIR}/sglang-env]: " SGLANG_VENV
    SGLANG_VENV=${SGLANG_VENV:-${SGLANG_DIR}/sglang-env}
    read -p "SGLang port [30000]: " SGLANG_PORT
    SGLANG_PORT=${SGLANG_PORT:-30000}
    SGLANG_HOST="localhost"
fi

# llama.cpp
LLAMACPP_ENABLED=false
read -p "llama.cpp directory (e.g., /home/user/llama.cpp) [skip]: " LLAMACPP_DIR
if [ ! -z "$LLAMACPP_DIR" ]; then
    if [ ! -d "$LLAMACPP_DIR" ]; then
        echo "⚠️  Directory not found: $LLAMACPP_DIR"
        read -p "Continue anyway? (y/n): " CONT
        [[ ! "$CONT" =~ ^[Yy]$ ]] && LLAMACPP_DIR=""
    fi
fi

if [ ! -z "$LLAMACPP_DIR" ]; then
    LLAMACPP_ENABLED=true
    read -p "llama.cpp binary [${LLAMACPP_DIR}/build/bin/llama-server]: " LLAMACPP_BIN
    LLAMACPP_BIN=${LLAMACPP_BIN:-${LLAMACPP_DIR}/build/bin/llama-server}
    read -p "llama.cpp port [8085]: " LLAMACPP_PORT
    LLAMACPP_PORT=${LLAMACPP_PORT:-8085}
    LLAMACPP_HOST="localhost"
fi

# TabbyAPI
TABBY_ENABLED=false
read -p "TabbyAPI directory (e.g., /home/user/TabbyAPI) [skip]: " TABBY_DIR
if [ ! -z "$TABBY_DIR" ]; then
    if [ ! -d "$TABBY_DIR" ]; then
        echo "⚠️  Directory not found: $TABBY_DIR"
        read -p "Continue anyway? (y/n): " CONT
        [[ ! "$CONT" =~ ^[Yy]$ ]] && TABBY_DIR=""
    fi
fi

if [ ! -z "$TABBY_DIR" ]; then
    TABBY_ENABLED=true
    read -p "TabbyAPI venv path [${TABBY_DIR}/venv]: " TABBY_VENV
    TABBY_VENV=${TABBY_VENV:-${TABBY_DIR}/venv}
    read -p "TabbyAPI model directory [/opt/models]: " TABBY_MODEL_DIR
    TABBY_MODEL_DIR=${TABBY_MODEL_DIR:-/opt/models}
    read -p "TabbyAPI port [5000]: " TABBY_PORT
    TABBY_PORT=${TABBY_PORT:-5000}
    TABBY_HOST="localhost"
    TABBY_TOKENS_PATH="$TABBY_DIR/api_tokens.yml"
    TABBY_CONFIG_PATH="$TABBY_DIR/config.yml"
    
    # Check if Blackwell GPU
    if nvidia-smi --query-gpu=compute_cap --format=csv,noheader | grep -q "12.0"; then
        echo "✓ Detected Blackwell GPU - will set TORCH_CUDA_ARCH_LIST workaround"
        TABBY_NEEDS_WORKAROUND=true
    else
        TABBY_NEEDS_WORKAROUND=false
    fi
fi

echo ""
echo "=== Summary ===" 
echo "Install directory: $INSTALL_DIR"
echo "Router port: $ROUTER_PORT"
echo "Run as user: $RUN_USER"
echo ""
echo "Backends:"
[ "$SGLANG_ENABLED" = true ] && echo "  ✓ SGLang: $SGLANG_DIR (port $SGLANG_PORT)"
[ "$LLAMACPP_ENABLED" = true ] && echo "  ✓ llama.cpp: $LLAMACPP_DIR (port $LLAMACPP_PORT)"
[ "$TABBY_ENABLED" = true ] && echo "  ✓ TabbyAPI: $TABBY_DIR (port $TABBY_PORT)"
echo ""

read -p "Proceed with installation? (y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo "=== Installing ===" 

# Create directories
mkdir -p $INSTALL_DIR

# Copy router application and management script
cp router.py $INSTALL_DIR/
chmod +x $INSTALL_DIR/router.py
cp manage-models.sh $INSTALL_DIR/
chmod +x $INSTALL_DIR/manage-models.sh

# Create Python virtual environment
echo "Creating Python virtual environment..."
$PYTHON_CMD -m venv $PYTHON_ENV
$PYTHON_ENV/bin/pip install --upgrade pip > /dev/null
$PYTHON_ENV/bin/pip install fastapi uvicorn httpx pyyaml > /dev/null
echo "✓ Python dependencies installed"

# Generate config.json
BACKENDS_JSON=""
BACKEND_COUNT=0

if [ "$SGLANG_ENABLED" = true ]; then
    if [ $BACKEND_COUNT -gt 0 ]; then BACKENDS_JSON="$BACKENDS_JSON,"; fi
    BACKENDS_JSON="$BACKENDS_JSON
    \"sglang\": {
      \"port\": $SGLANG_PORT,
      \"host\": \"$SGLANG_HOST\",
      \"health_endpoint\": \"/health\"
    }"
    BACKEND_COUNT=$((BACKEND_COUNT + 1))
fi

if [ "$TABBY_ENABLED" = true ]; then
    if [ $BACKEND_COUNT -gt 0 ]; then BACKENDS_JSON="$BACKENDS_JSON,"; fi
    BACKENDS_JSON="$BACKENDS_JSON
    \"tabbyapi\": {
      \"port\": $TABBY_PORT,
      \"host\": \"$TABBY_HOST\",
      \"health_endpoint\": \"/health\"
    }"
    BACKEND_COUNT=$((BACKEND_COUNT + 1))
fi

if [ "$LLAMACPP_ENABLED" = true ]; then
    if [ $BACKEND_COUNT -gt 0 ]; then BACKENDS_JSON="$BACKENDS_JSON,"; fi
    BACKENDS_JSON="$BACKENDS_JSON
    \"llamacpp\": {
      \"port\": $LLAMACPP_PORT,
      \"host\": \"$LLAMACPP_HOST\",
      \"health_endpoint\": \"/health\"
    }"
fi

cat > $INSTALL_DIR/config.json << EOFCONFIG
{
  "router_port": $ROUTER_PORT,
  "model_load_timeout": 300,
  "backends": {$BACKENDS_JSON
  },
  "models": {}
}
EOFCONFIG

echo "✓ Configuration created at $INSTALL_DIR/config.json"

# Create backend wrapper scripts
if [ "$SGLANG_ENABLED" = true ]; then
    cat > $INSTALL_DIR/start-sglang.sh << 'EOFSGLANG'
#!/bin/bash
MODEL_PATH=$(python3 -c "
import json, sys
with open('/opt/llm-router/config.json') as f:
    config = json.load(f)
for name, info in config['models'].items():
    if info['backend'] == 'sglang':
        print(info['model_path'])
        sys.exit(0)
print('ERROR: No SGLang model configured', file=sys.stderr)
sys.exit(1)
")
if [ $? -ne 0 ]; then exit 1; fi
cd SGLANG_DIR_PLACEHOLDER
exec SGLANG_VENV_PLACEHOLDER/bin/python -m sglang.launch_server \
    --model-path "$MODEL_PATH" \
    --host 0.0.0.0 \
    --port SGLANG_PORT_PLACEHOLDER \
    --quantization awq
EOFSGLANG
    sed -i "s|SGLANG_DIR_PLACEHOLDER|$SGLANG_DIR|g" $INSTALL_DIR/start-sglang.sh
    sed -i "s|SGLANG_VENV_PLACEHOLDER|$SGLANG_VENV|g" $INSTALL_DIR/start-sglang.sh
    sed -i "s|SGLANG_PORT_PLACEHOLDER|$SGLANG_PORT|g" $INSTALL_DIR/start-sglang.sh
    chmod +x $INSTALL_DIR/start-sglang.sh
    echo "✓ Created SGLang wrapper script"
fi

if [ "$LLAMACPP_ENABLED" = true ]; then
    cat > $INSTALL_DIR/start-llamacpp.sh << 'EOFLLAMACPP'
#!/bin/bash
MODEL_PATH=$(python3 -c "
import json, sys
with open('/opt/llm-router/config.json') as f:
    config = json.load(f)
for name, info in config['models'].items():
    if info['backend'] == 'llamacpp':
        print(info['model_path'])
        sys.exit(0)
print('ERROR: No llama.cpp model configured', file=sys.stderr)
sys.exit(1)
")
if [ $? -ne 0 ]; then exit 1; fi
cd LLAMACPP_DIR_PLACEHOLDER
export LD_LIBRARY_PATH=LLAMACPP_DIR_PLACEHOLDER/build/bin
exec LLAMACPP_BIN_PLACEHOLDER \
    -m "$MODEL_PATH" \
    --host 0.0.0.0 \
    --port LLAMACPP_PORT_PLACEHOLDER
EOFLLAMACPP
    sed -i "s|LLAMACPP_DIR_PLACEHOLDER|$LLAMACPP_DIR|g" $INSTALL_DIR/start-llamacpp.sh
    sed -i "s|LLAMACPP_BIN_PLACEHOLDER|$LLAMACPP_BIN|g" $INSTALL_DIR/start-llamacpp.sh
    sed -i "s|LLAMACPP_PORT_PLACEHOLDER|$LLAMACPP_PORT|g" $INSTALL_DIR/start-llamacpp.sh
    chmod +x $INSTALL_DIR/start-llamacpp.sh
    echo "✓ Created llama.cpp wrapper script"
fi

# Create systemd services
if [ "$SGLANG_ENABLED" = true ]; then
    cat > /etc/systemd/system/sglang.service << EOFSVC
[Unit]
Description=SGLang Server - AWQ Backend
After=network.target

[Service]
Type=simple
User=$RUN_USER
WorkingDirectory=$SGLANG_DIR
ExecStart=$INSTALL_DIR/start-sglang.sh
Restart=no
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOFSVC
    echo "✓ Created sglang.service"
fi

if [ "$LLAMACPP_ENABLED" = true ]; then
    cat > /etc/systemd/system/llamacpp.service << EOFSVC
[Unit]
Description=llama.cpp Server - GGUF Backend
After=network.target

[Service]
Type=simple
User=$RUN_USER
WorkingDirectory=$LLAMACPP_DIR
ExecStart=$INSTALL_DIR/start-llamacpp.sh
Restart=no
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOFSVC
    echo "✓ Created llamacpp.service"
fi

if [ "$TABBY_ENABLED" = true ]; then
    TABBY_ENV=""
    if [ "$TABBY_NEEDS_WORKAROUND" = true ]; then
        TABBY_ENV="Environment=\"TORCH_CUDA_ARCH_LIST=8.9;9.0\""
    fi
    cat > /etc/systemd/system/tabbyapi.service << EOFSVC
[Unit]
Description=TabbyAPI Server - EXL2 Backend
After=network.target

[Service]
Type=simple
User=$RUN_USER
WorkingDirectory=$TABBY_DIR
$TABBY_ENV
Environment="PATH=$TABBY_VENV/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=$TABBY_VENV/bin/python main.py --model-dir $TABBY_MODEL_DIR
Restart=no
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOFSVC
    echo "✓ Created tabbyapi.service"
fi

# Create router systemd service
cat > /etc/systemd/system/llm-router.service << EOFSVC
[Unit]
Description=Multi-Backend LLM Router v4.0.0
After=network.target

[Service]
Type=simple
User=$RUN_USER
WorkingDirectory=$INSTALL_DIR
Environment="ROUTER_CONFIG=$INSTALL_DIR/config.json"
Environment="TABBY_TOKENS_PATH=$TABBY_TOKENS_PATH"
Environment="TABBY_CONFIG_PATH=$TABBY_CONFIG_PATH"
Environment="TABBY_MODEL_DIR=$TABBY_MODEL_DIR"
Environment="PATH=$PYTHON_ENV/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=$PYTHON_ENV/bin/python $INSTALL_DIR/router.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOFSVC

systemctl daemon-reload
echo "✓ Systemd services created and loaded"

echo ""
echo "=========================================="
echo "✅ Installation Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Add your models:"
echo "   $INSTALL_DIR/manage-models.sh"
echo ""
echo "2. Start the router:"
echo "   sudo systemctl start llm-router"
echo ""
echo "3. Check status:"
echo "   sudo systemctl status llm-router"
echo ""
echo "4. Configure Open-WebUI to use:"
echo "   http://localhost:$ROUTER_PORT"
echo ""
echo "Backend services created:"
[ "$SGLANG_ENABLED" = true ] && echo "  - sglang.service"
[ "$LLAMACPP_ENABLED" = true ] && echo "  - llamacpp.service"
[ "$TABBY_ENABLED" = true ] && echo "  - tabbyapi.service"
echo ""
echo "These will auto-start when you select a model in Open-WebUI!"
