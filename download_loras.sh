#!/bin/bash
cd /models/loras || exit 1

# Function to download a file with proper URL encoding
download_file() {
  filename="$1"
  # URL encode the filename for the URL
  encoded_url=$(echo "$filename" | sed -e "s/ /%20/g")
  echo "Downloading $filename..."
  wget -q -O "$filename" "https://d1s3da0dcaf6kx.cloudfront.net/$encoded_url" || {
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