#!/bin/bash

# LoRA Batch Downloader
# Downloads multiple LoRA models from CivitAI using model version IDs from a file

set -e  # Exit on any error

# Configuration
LORA_DIR="/models/loras"
DOWNLOAD_SCRIPT="download_with_aria.py"

# Parse command line arguments
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -f, --file FILE     Model IDs file (default: model_version_ids.txt)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "File format examples:"
    echo "  Comma-separated: 2091879, 2091870, 2077123"
    echo "  Space-separated: 2091879 2091870 2077123"
    echo "  One per line:"
    echo "    2091879"
    echo "    2091870"
    echo "    2077123"
}

# Default values
MODEL_IDS_FILE="model_version_ids.txt"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            MODEL_IDS_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Create directory if it doesn't exist
mkdir -p "$LORA_DIR"
cd "$LORA_DIR" || exit 1

echo "📁 Working directory: $(pwd)"

# Download the download script from GitHub if it doesn't exist
if [[ ! -f "$DOWNLOAD_SCRIPT" ]]; then
    echo "📥 Downloading $DOWNLOAD_SCRIPT from GitHub..."
    GITHUB_URL="https://raw.githubusercontent.com/Hearmeman24/CivitAI_Downloader/main/download_with_aria.py"

    if command -v curl &> /dev/null; then
        curl -L -o "$DOWNLOAD_SCRIPT" "$GITHUB_URL" || {
            echo "❌ Failed to download $DOWNLOAD_SCRIPT using curl"
            exit 1
        }
    elif command -v wget &> /dev/null; then
        wget -O "$DOWNLOAD_SCRIPT" "$GITHUB_URL" || {
            echo "❌ Failed to download $DOWNLOAD_SCRIPT using wget"
            exit 1
        }
    else
        echo "❌ Error: Neither curl nor wget found. Installing wget..."
        apt-get update
        apt-get install -y wget
        wget -O "$DOWNLOAD_SCRIPT" "$GITHUB_URL" || {
            echo "❌ Failed to download $DOWNLOAD_SCRIPT"
            exit 1
        }
    fi

    echo "✅ Successfully downloaded $DOWNLOAD_SCRIPT"
    chmod +x "$DOWNLOAD_SCRIPT"
else
    echo "✅ $DOWNLOAD_SCRIPT already exists"
fi

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 not found. Installing..."
    apt-get update
    apt-get install -y python3 python3-pip
fi

# Check if aria2 is available
if ! command -v aria2c &> /dev/null; then
    echo "📥 Installing aria2..."
    apt-get update
    apt-get install -y aria2
fi

# Install required Python packages if needed
echo "📦 Installing Python dependencies..."
pip3 install requests

# Check if CIVITAI_TOKEN is set
if [[ -z "$CIVITAI_TOKEN" ]]; then
    echo "⚠️  Warning: CIVITAI_TOKEN environment variable not set"
    echo "   Some models may require authentication to download"
    echo "   Set the token with: export CIVITAI_TOKEN='your_token_here'"
fi

# Function to download a single model
download_model() {
    local model_id="$1"
    echo ""
    echo "📥 Downloading model version ID: $model_id"

    if python3 "$DOWNLOAD_SCRIPT" -m "$model_id" -o .; then
        echo "✅ Successfully downloaded model $model_id"
        return 0
    else
        echo "❌ Failed to download model $model_id"
        return 1
    fi
}

# Function to load model IDs from file
load_model_ids() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "❌ Error: Model IDs file '$file' not found" >&2
        echo "   Looking for file at: $(realpath "$file" 2>/dev/null || echo "$file")" >&2
        echo "   Current directory: $(pwd)" >&2
        echo "   Files in current directory:" >&2
        ls -la >&2
        exit 1
    fi

    echo "📄 Loading model IDs from: $file" >&2

    # Read file and extract numbers, handling various formats
    local -a ids=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Extract all numbers from the line (handles comma-separated, space-separated, etc.)
        while read -r id; do
            if [[ "$id" =~ ^[0-9]+$ ]]; then
                ids+=("$id")
            fi
        done < <(echo "$line" | grep -oE '[0-9]+')
    done < "$file"

    if [[ ${#ids[@]} -eq 0 ]]; then
        echo "❌ Error: No valid model IDs found in $file" >&2
        echo "   Expected format: comma-separated or space-separated numbers" >&2
        echo "   Example: 2091879, 2091870, 2077123" >&2
        echo "   or one ID per line" >&2
        echo "   File contents:" >&2
        cat "$file" >&2
        exit 1
    fi

    echo "✅ Loaded ${#ids[@]} model IDs from file" >&2
    # Output each ID on a separate line for mapfile (to stdout only)
    printf '%s\n' "${ids[@]}"
}

# Check if the model IDs file exists (look in multiple locations)
if [[ ! -f "$MODEL_IDS_FILE" ]]; then
    # Try different possible locations
    for possible_path in \
        "$MODEL_IDS_FILE" \
        "/tmp/$MODEL_IDS_FILE" \
        "/models/loras/$MODEL_IDS_FILE" \
        "$(dirname "$0")/$MODEL_IDS_FILE"; do

        if [[ -f "$possible_path" ]]; then
            MODEL_IDS_FILE="$possible_path"
            echo "✅ Found model IDs file at: $MODEL_IDS_FILE"
            break
        fi
    done
fi

# Load model IDs from file
echo "🔍 Loading model IDs..."
mapfile -t MODEL_IDS < <(load_model_ids "$MODEL_IDS_FILE")

# Debug: Show loaded IDs
echo "🔍 Debug: Loaded model IDs:"
printf '  %s\n' "${MODEL_IDS[@]}"

# Download statistics
total_models=${#MODEL_IDS[@]}
successful_downloads=0
failed_downloads=0

echo ""
echo "🚀 Starting batch download of $total_models LoRA models..."
echo "============================================================"

# Download each model
for model_id in "${MODEL_IDS[@]}"; do
    if download_model "$model_id"; then
        ((successful_downloads++))
    else
        ((failed_downloads++))
        echo "   Continuing with next model..."
    fi
done

echo ""
echo "============================================================"
echo "📊 Download Summary:"
echo "   Total models: $total_models"
echo "   Successful: $successful_downloads"
echo "   Failed: $failed_downloads"

if [[ $failed_downloads -eq 0 ]]; then
    echo "✅ All LoRA files downloaded successfully!"
    exit 0
else
    echo "⚠️  Some downloads failed. Check the output above for details."
    exit 1
fi