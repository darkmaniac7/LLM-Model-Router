#!/bin/bash
set -e

echo "=========================================="
echo "Multi-Backend LLM Router Installer"
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
echo "Enter backend details (leave port empty to skip)"
echo ""

# SGLang
read -p "SGLang host [localhost]: " SGLANG_HOST
SGLANG_HOST=${SGLANG_HOST:-localhost}
read -p "SGLang port [30000] (empty to disable): " SGLANG_PORT
SGLANG_PORT=${SGLANG_PORT:-30000}
read -p "SGLang service name [sglang.service]: " SGLANG_SERVICE
SGLANG_SERVICE=${SGLANG_SERVICE:-sglang.service}

# vLLM
read -p "vLLM host [localhost]: " VLLM_HOST
VLLM_HOST=${VLLM_HOST:-localhost}
read -p "vLLM port [8000] (empty to disable): " VLLM_PORT
VLLM_PORT=${VLLM_PORT:-8000}
read -p "vLLM service name [vllm.service]: " VLLM_SERVICE
VLLM_SERVICE=${VLLM_SERVICE:-vllm.service}

# TabbyAPI
read -p "TabbyAPI host [localhost]: " TABBY_HOST
TABBY_HOST=${TABBY_HOST:-localhost}
read -p "TabbyAPI port [5000] (empty to disable): " TABBY_PORT
TABBY_PORT=${TABBY_PORT:-5000}
read -p "TabbyAPI service name [tabbyapi.service]: " TABBY_SERVICE
TABBY_SERVICE=${TABBY_SERVICE:-tabbyapi.service}

echo ""
echo "=== Summary ===" 
echo "Install directory: $INSTALL_DIR"
echo "Python environment: $PYTHON_ENV"
echo "Router port: $ROUTER_PORT"
echo "Run as user: $RUN_USER"
echo ""
echo "Backends:"
[ ! -z "$SGLANG_PORT" ] && echo "  - SGLang: $SGLANG_HOST:$SGLANG_PORT"
[ ! -z "$VLLM_PORT" ] && echo "  - vLLM: $VLLM_HOST:$VLLM_PORT"
[ ! -z "$TABBY_PORT" ] && echo "  - TabbyAPI: $TABBY_HOST:$TABBY_PORT"
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
mkdir -p /etc/llm-router

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
cat > /etc/llm-router/config.json << 'EOFCONFIG'
{
  "router_port": ROUTER_PORT_PLACEHOLDER,
  "model_load_timeout": 300,
  "backends": {
EOFCONFIG

# Add backends to JSON
BACKENDS_JSON=""
BACKEND_COUNT=0

if [ ! -z "$SGLANG_PORT" ]; then
    if [ $BACKEND_COUNT -gt 0 ]; then
        BACKENDS_JSON="$BACKENDS_JSON,"
    fi
    BACKENDS_JSON="$BACKENDS_JSON
    \"sglang\": {
      \"port\": $SGLANG_PORT,
      \"host\": \"$SGLANG_HOST\",
      \"health_endpoint\": \"/health\"
    }"
    BACKEND_COUNT=$((BACKEND_COUNT + 1))
fi

if [ ! -z "$TABBY_PORT" ]; then
    if [ $BACKEND_COUNT -gt 0 ]; then
        BACKENDS_JSON="$BACKENDS_JSON,"
    fi
    BACKENDS_JSON="$BACKENDS_JSON
    \"tabbyapi\": {
      \"port\": $TABBY_PORT,
      \"host\": \"$TABBY_HOST\",
      \"health_endpoint\": \"/health\"
    }"
    BACKEND_COUNT=$((BACKEND_COUNT + 1))
fi

if [ ! -z "$VLLM_PORT" ]; then
    if [ $BACKEND_COUNT -gt 0 ]; then
        BACKENDS_JSON="$BACKENDS_JSON,"
    fi
    BACKENDS_JSON="$BACKENDS_JSON
    \"llamacpp\": {
      \"port\": 8085,
      \"host\": \"localhost\",
      \"health_endpoint\": \"/health\"
    }"
fi

cat >> /etc/llm-router/config.json << EOFCONFIG
$BACKENDS_JSON
  },
  "models": {}
}
EOFCONFIG

# Replace router port placeholder
sed -i "s/ROUTER_PORT_PLACEHOLDER/$ROUTER_PORT/" /etc/llm-router/config.json

echo "✓ Configuration created at /etc/llm-router/config.json"
echo ""
echo "To add models, use the management script:"
echo "  $INSTALL_DIR/manage-models.sh"
echo "Or manually edit: /etc/llm-router/config.json"

# Create systemd service
cat > /etc/systemd/system/llm-router.service << EOFSERVICE
[Unit]
Description=Multi-Backend LLM Router
After=network.target

[Service]
Type=simple
User=$RUN_USER
WorkingDirectory=$INSTALL_DIR
Environment="ROUTER_CONFIG=/etc/llm-router/config.json"
Environment="PATH=$PYTHON_ENV/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=$PYTHON_ENV/bin/python $INSTALL_DIR/router.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOFSERVICE

systemctl daemon-reload
echo "✓ Systemd service created"

echo ""
echo "=========================================="
echo "✅ Installation Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Add your models using the management script:"
echo "   $INSTALL_DIR/manage-models.sh"
echo ""
echo "2. Start the router:"
echo "   sudo systemctl start llm-router"
echo ""
echo "3. Enable auto-start on boot:"
echo "   sudo systemctl enable llm-router"
echo ""
echo "4. Check status:"
echo "   sudo systemctl status llm-router"
echo ""
echo "5. View logs:"
echo "   journalctl -u llm-router -f"
echo ""
echo "Router will be available at: http://localhost:$ROUTER_PORT"
echo "OpenAI-compatible API: http://localhost:$ROUTER_PORT/v1/chat/completions"
echo ""
echo "Model management:"
echo "  Add model:    $INSTALL_DIR/manage-models.sh add"
echo "  List models:  $INSTALL_DIR/manage-models.sh list"
echo "  Remove model: $INSTALL_DIR/manage-models.sh remove"
echo ""
