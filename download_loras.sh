#!/bin/bash
cd /models/loras || exit 1

# Function to download a file with proper URL encoding
download_file() {
  filename="$1"
  # Check if filename contains spaces or other special characters
  if [[ "$filename" =~ [^a-zA-Z0-9._-] ]]; then
    # Encode spaces only (or extend this if needed)
    encoded_url=$(echo "$filename" | sed -e "s/ /%20/g")
  else
    encoded_url="$filename"
  fi

  echo "Downloading $filename..."
  wget -q --timeout=30 --tries=3 -O "$filename" "https://d1s3da0dcaf6kx.cloudfront.net/$encoded_url" || {
    echo "Failed to download $filename"
    return 1
  }
  echo "Successfully downloaded $filename"
  return 0
}

# Download all LoRA files
download_file "wan2.2-i2v-high-oral-insertion-v1.0.safetensors"
download_file "wan2.2-i2v-low-oral-insertion-v1.0.safetensors"


echo "All LoRA files downloaded successfully"