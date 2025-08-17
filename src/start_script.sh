#!/usr/bin/env bash
set -euo pipefail

BRANCH="master"

# Check if directory exists and remove it or update it
if [ -d "wan22" ]; then
  echo "📂 Directory already exists. Removing it first..."
  rm -rf wan22
fi

echo "📥 Cloning branch '$BRANCH' of Wan22…"
git clone --branch "$BRANCH" https://github.com/Hearmeman24/wan22.git

echo "📂 Moving start.sh into place…"
mv wan22/src/start.sh /

echo "▶️ Running start.sh"
bash /start.sh