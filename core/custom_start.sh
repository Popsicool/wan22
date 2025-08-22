#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

echo "🚀 Starting custom ComfyUI with existing network volume setup..."

# Set the network volume path
NETWORK_VOLUME="/workspace"

# Check if NETWORK_VOLUME exists
if [ ! -d "$NETWORK_VOLUME" ]; then
    echo "❌ ERROR: NETWORK_VOLUME directory '$NETWORK_VOLUME' does not exist!"
    echo "This container requires a network volume mounted at /workspace"
    exit 1
fi

echo "✅ Network volume found at: $NETWORK_VOLUME"

# Check if ComfyUI exists in network volume
COMFYUI_DIR="$NETWORK_VOLUME/ComfyUI"
if [ ! -d "$COMFYUI_DIR" ]; then
    echo "❌ ERROR: ComfyUI not found at $COMFYUI_DIR"
    echo "Please ensure your network volume has ComfyUI installed at /workspace/ComfyUI"
    exit 1
fi

echo "✅ ComfyUI found at: $COMFYUI_DIR"

# Start JupyterLab (optional - remove if you don't need it)
echo "🔬 Starting JupyterLab..."
jupyter-lab --ip=0.0.0.0 --allow-root --no-browser --NotebookApp.token='' --NotebookApp.password='' --ServerApp.allow_origin='*' --ServerApp.allow_credentials=True --notebook-dir=/workspace &

# Check for additional setup script
if [ -f "/workspace/additional_params.sh" ]; then
    chmod +x /workspace/additional_params.sh
    echo "🔧 Executing additional_params.sh..."
    /workspace/additional_params.sh
else
    echo "ℹ️  additional_params.sh not found in /workspace. Skipping..."
fi

# Set working directory to network volume
cd "$NETWORK_VOLUME"
echo "📂 Working directory: $(pwd)"

# Download CivitAI models if specified (only if environment variables are set and not default values)
if [ -n "$CHECKPOINT_IDS_TO_DOWNLOAD" ] && [ "$CHECKPOINT_IDS_TO_DOWNLOAD" != "replace_with_ids" ] && [ "$CHECKPOINT_IDS_TO_DOWNLOAD" != "" ]; then
    echo "📥 Downloading checkpoint models..."
    mkdir -p "$NETWORK_VOLUME/ComfyUI/models/checkpoints"
    cd "$NETWORK_VOLUME/ComfyUI/models/checkpoints"
    
    # Download CivitAI script if not present
    if [ ! -f "/usr/local/bin/download.py" ]; then
        echo "📥 Getting CivitAI download script..."
        git clone "https://github.com/Hearmeman24/CivitAI_Downloader.git" /tmp/civitai_downloader
        cp /tmp/civitai_downloader/download.py /usr/local/bin/
        chmod +x /usr/local/bin/download.py
        rm -rf /tmp/civitai_downloader
    fi
    
    IFS=',' read -ra CHECKPOINT_IDS <<< "$CHECKPOINT_IDS_TO_DOWNLOAD"
    for CHECKPOINT_ID in "${CHECKPOINT_IDS[@]}"; do
        echo "📥 Downloading checkpoint: $CHECKPOINT_ID"
        /usr/local/bin/download.py --model "$CHECKPOINT_ID"
    done
fi

if [ -n "$LORAS_IDS_TO_DOWNLOAD" ] && [ "$LORAS_IDS_TO_DOWNLOAD" != "replace_with_ids" ] && [ "$LORAS_IDS_TO_DOWNLOAD" != "" ]; then
    echo "📥 Downloading LoRA models..."
    mkdir -p "$NETWORK_VOLUME/ComfyUI/models/loras"
    cd "$NETWORK_VOLUME/ComfyUI/models/loras"
    
    # Download CivitAI script if not present
    if [ ! -f "/usr/local/bin/download.py" ]; then
        echo "📥 Getting CivitAI download script..."
        git clone "https://github.com/Hearmeman24/CivitAI_Downloader.git" /tmp/civitai_downloader
        cp /tmp/civitai_downloader/download.py /usr/local/bin/
        chmod +x /usr/local/bin/download.py
        rm -rf /tmp/civitai_downloader
    fi
    
    IFS=',' read -ra LORA_IDS <<< "$LORAS_IDS_TO_DOWNLOAD"
    for LORA_ID in "${LORA_IDS[@]}"; do
        echo "📥 Downloading LoRA: $LORA_ID"
        /usr/local/bin/download.py --model "$LORA_ID"
    done
fi

# Ensure we're in the ComfyUI directory
cd "$COMFYUI_DIR"

# Copy extra model paths config if it exists
if [ -f "/extra_model_paths.yml" ]; then
    cp /extra_model_paths.yml "$COMFYUI_DIR/"
    echo "✅ Copied extra model paths config"
fi

echo "🎨 Starting ComfyUI server..."
echo "📍 ComfyUI directory: $COMFYUI_DIR"
echo "🌐 Server will be available on port 8188"

# Start ComfyUI with the existing installation
if [ "$enable_optimizations" = "true" ]; then
    echo "⚡ Starting with optimizations enabled..."
    python3 main.py --listen 0.0.0.0 --port 8188 --use-sage-attention
    if [ $? -ne 0 ]; then
        echo "⚠️  ComfyUI failed with optimizations, retrying without..."
        python3 main.py --listen 0.0.0.0 --port 8188
    fi
else
    echo "🔧 Starting in standard mode..."
    python3 main.py --listen 0.0.0.0 --port 8188
fi