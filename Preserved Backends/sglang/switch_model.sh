#!/bin/bash
# Quick model switcher for SGLang

if [ -z "$1" ]; then
    echo "Usage: $0 <model_name>"
    echo ""
    echo "Available models:"
    echo "  mistral     - Mistral-Large-Instruct-2411-AWQ"
    echo "  llama33     - Llama 3.3 70B Instruct Abliterated AWQ"
    echo "  deepseek    - DeepSeek-R1-Distill-Llama-70B-AWQ"
    echo "  glm         - GLM-4.5-Air-AWQ"
    echo "  magnum      - Magnum-v4-123B-AWQ (NEW!)"
    exit 1
fi

MODEL=$1

case $MODEL in
    mistral)
        SCRIPT="start_sglang_mistral_tp4_compiled.sh"
        ;;
    llama33)
        SCRIPT="start_sglang_llama33_tp4_compiled.sh"
        ;;
    deepseek)
        SCRIPT="start_sglang_deepseek_tp4_compiled.sh"
        ;;
    glm)
        SCRIPT="start_sglang_glm_tp4_compiled.sh"
        ;;
    magnum)
        SCRIPT="start_sglang_magnum.sh"
        ;;
    *)
        echo "Unknown model: $MODEL"
        exit 1
        ;;
esac

# Update systemd service
sudo sed -i "s|ExecStart=.*|ExecStart=/home/ivan/sglang/$SCRIPT|" /etc/systemd/system/sglang.service

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart sglang.service

echo "Switching to $MODEL..."
echo "Monitor with: sudo journalctl -u sglang.service -f"
echo "Or check logs: tail -f /home/ivan/sglang/sglang.log"
