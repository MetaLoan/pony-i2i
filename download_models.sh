#!/bin/bash
echo "🚀 Pony i2i 模型下载脚本"
echo "目标路径: /workspace/models/"

# Civitai Token 必须设置
if [ -z "$CIVITAI_TOKEN" ]; then
  echo "❌ 请先设置 CIVITAI_TOKEN 环境变量"
  echo "   export CIVITAI_TOKEN=your_token_here"
  exit 1
fi

MODEL_DIR="/workspace/models"
mkdir -p $MODEL_DIR/checkpoints
mkdir -p $MODEL_DIR/loras

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36"

# ===== Checkpoint =====

echo "📥 [1/2] 下载 Pony Realism v2.3 ULTRA (~6.6GB)..."
curl -# -L -A "$UA" \
  -H "Authorization: Bearer ${CIVITAI_TOKEN}" \
  "https://civitai.com/api/download/models/1920896" \
  -o $MODEL_DIR/checkpoints/ponyRealism_V23ULTRA.safetensors

# ===== LoRA =====

echo "📥 [2/2] 下载 Pony Amateur V3 CC & Grain (~325MB)..."
curl -# -L -A "$UA" \
  -H "Authorization: Bearer ${CIVITAI_TOKEN}" \
  "https://civitai.com/api/download/models/1359711" \
  -o $MODEL_DIR/loras/AmateurStyle_v3_PONY_REALISM.safetensors

echo ""
echo "🔍 验证文件："
echo "=== checkpoints ==="
ls -lh $MODEL_DIR/checkpoints/
echo "=== loras ==="
ls -lh $MODEL_DIR/loras/
echo ""
echo "✅ 下载完毕！共 2 个模型（1 Checkpoint + 1 LoRA）"
