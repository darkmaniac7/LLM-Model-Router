#!/bin/bash

# Easy Model Management Script for LLM Router
# This script helps non-technical users add/update models

CONFIG_FILE="/opt/llm-router/config.json"

show_header() {
    echo "=========================================="
    echo "   LLM Router - Model Management"
    echo "=========================================="
    echo ""
}

list_models() {
    echo "Current Models:"
    echo ""
    if [ -f "$CONFIG_FILE" ]; then
        python3 - <<'PYEOF'
import json
import sys
try:
    with open("/opt/llm-router/config.json") as f:
        config = json.load(f)
    if "models" in config and config["models"]:
        for name, settings in config["models"].items():
            print(f"  • {name}")
            print(f"    Backend: {settings.get('backend', 'N/A')}")
            print(f"    Path: {settings.get('model_path', 'N/A')}")
            print("")
    else:
        print("  No models configured yet.")
except Exception as e:
    print(f"  Error reading config: {e}")
PYEOF
    else
        echo "  Config file not found."
    fi
    echo ""
}

add_model() {
    echo "Add New Model"
    echo "-------------"
    echo ""
    
    read -p "Model name (e.g., kat-dev-q4): " MODEL_NAME
    if [ -z "$MODEL_NAME" ]; then
        echo "Error: Model name cannot be empty"
        return 1
    fi
    
    echo ""
    echo "Select backend:"
    echo "1) llama.cpp (for GGUF models)"
    echo "2) sglang (for AWQ models)"
    echo "3) tabbyapi (for EXL2 models)"
    read -p "Enter number (1-3): " BACKEND_CHOICE
    
    case $BACKEND_CHOICE in
        1) BACKEND="llamacpp" ;;
        2) BACKEND="sglang" ;;
        3) BACKEND="tabbyapi" ;;
        *) echo "Invalid choice"; return 1 ;;
    esac
    
    echo ""
    read -p "Full path to model: " MODEL_PATH
    if [ ! -e "$MODEL_PATH" ]; then
        echo "Warning: Path does not exist: $MODEL_PATH"
        read -p "Continue anyway? (y/n): " CONTINUE
        if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    # Add model to config
    python3 - "$MODEL_NAME" "$BACKEND" "$MODEL_PATH" <<'PYEOF'
import json
import sys

model_name = sys.argv[1]
backend = sys.argv[2]
model_path = sys.argv[3]

try:
    with open("/opt/llm-router/config.json", "r") as f:
        config = json.load(f)
except FileNotFoundError:
    config = {"models": {}, "backends": {}}

if "models" not in config:
    config["models"] = {}

config["models"][model_name] = {
    "backend": backend,
    "model_path": model_path
}

with open("/opt/llm-router/config.json", "w") as f:
    json.dump(config, f, indent=2)

print(f"\n✓ Model '{model_name}' added successfully!")
PYEOF
    
    echo ""
    read -p "Restart router service now? (y/n): " RESTART
    if [[ "$RESTART" =~ ^[Yy]$ ]]; then
        echo "Restarting router..."
        systemctl restart llm-router.service
        echo "Done!"
    fi
}

remove_model() {
    echo "Remove Model"
    echo "------------"
    echo ""
    
    list_models
    
    read -p "Model name to remove: " MODEL_NAME
    if [ -z "$MODEL_NAME" ]; then
        echo "Error: Model name cannot be empty"
        return 1
    fi
    
    python3 - "$MODEL_NAME" <<'PYEOF'
import json
import sys

model_name = sys.argv[1]

try:
    with open("/opt/llm-router/config.json", "r") as f:
        config = json.load(f)
    
    if "models" in config and model_name in config["models"]:
        del config["models"][model_name]
        
        with open("/opt/llm-router/config.json", "w") as f:
            json.dump(config, f, indent=2)
        
        print(f"\n✓ Model '{model_name}' removed successfully!")
    else:
        print(f"\nError: Model '{model_name}' not found")
except Exception as e:
    print(f"\nError: {e}")
PYEOF
}

# Main menu
show_header

if [ "$1" == "list" ]; then
    list_models
    exit 0
elif [ "$1" == "add" ]; then
    add_model
    exit 0
elif [ "$1" == "remove" ]; then
    remove_model
    exit 0
fi

while true; do
    echo "What would you like to do?"
    echo ""
    echo "1) List current models"
    echo "2) Add a new model"
    echo "3) Remove a model"
    echo "4) Exit"
    echo ""
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1) list_models ;;
        2) add_model ;;
        3) remove_model ;;
        4) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid choice. Please try again."; echo "" ;;
    esac
done
