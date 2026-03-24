#!/bin/bash
echo "🚀 Starting Pony i2i Worker..."

# Copy workflow and config to workspace
cp /workspace/pony_i2i_api.json /workspace/pony_i2i_api.json 2>/dev/null || true
cp /workspace/extra_model_paths.yaml /workspace/ComfyUI/extra_model_paths.yaml 2>/dev/null || true

python -u /workspace/runpod_worker.py
