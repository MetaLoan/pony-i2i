#!/bin/bash
# ==============================================
# Pony i2i 模型下载脚本
# 场景1 (测试 Pod):  bash download_models.sh test
# 场景2 (Network Volume / Serverless): bash download_models.sh
# ==============================================

MODE=${1:-"volume"}

if [ "$MODE" = "test" ]; then
  echo "🧪 测试模式 — 模型存到 /workspace/models/"
  MODEL_DIR="/workspace/models"
else
  echo "📦 Serverless 模式 — 模型存到 /runpod-volume/pony_models/"
  MODEL_DIR="/runpod-volume/pony_models"
fi

# Civitai Token
if [ -z "$CIVITAI_TOKEN" ]; then
  echo "❌ 请先设置 CIVITAI_TOKEN 环境变量"
  echo "   export CIVITAI_TOKEN=your_token_here"
  exit 1
fi

mkdir -p $MODEL_DIR/checkpoints
mkdir -p $MODEL_DIR/loras

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36"

# ===== Checkpoint =====

CKPT_FILE="$MODEL_DIR/checkpoints/ponyRealism_V23ULTRA.safetensors"
if [ -f "$CKPT_FILE" ]; then
  echo "✅ [1/2] Pony Realism v2.3 ULTRA 已存在 ($(du -h "$CKPT_FILE" | cut -f1))"
else
  echo "📥 [1/2] 下载 Pony Realism v2.3 ULTRA (~6.6GB)..."
  curl -# -L -A "$UA" \
    -H "Authorization: Bearer ${CIVITAI_TOKEN}" \
    "https://civitai.com/api/download/models/1920896" \
    -o "$CKPT_FILE"
fi

# ===== LoRA =====

LORA_FILE="$MODEL_DIR/loras/AmateurStyle_v3_PONY_REALISM.safetensors"
if [ -f "$LORA_FILE" ]; then
  echo "✅ [2/2] Pony Amateur V3 已存在 ($(du -h "$LORA_FILE" | cut -f1))"
else
  echo "📥 [2/2] 下载 Pony Amateur V3 CC & Grain (~325MB)..."
  curl -# -L -A "$UA" \
    -H "Authorization: Bearer ${CIVITAI_TOKEN}" \
    "https://civitai.com/api/download/models/1359711" \
    -o "$LORA_FILE"
fi

echo ""
echo "🔍 验证文件："
echo "=== checkpoints ==="
ls -lh $MODEL_DIR/checkpoints/
echo "=== loras ==="
ls -lh $MODEL_DIR/loras/
echo ""
echo "✅ 完毕！模型路径: $MODEL_DIR"
