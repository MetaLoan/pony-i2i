#!/bin/bash
# 快速测试脚本 - 在 RunPod GPU Pod 上运行此脚本来测试 i2i 工作流
# 使用方法: bash test_local.sh

COMFY_URL="http://127.0.0.1:8188"

echo "🧪 Pony i2i 本地测试"

# 检查 ComfyUI 是否运行
echo "检查 ComfyUI..."
if ! curl -s "$COMFY_URL/system_stats" > /dev/null 2>&1; then
  echo "❌ ComfyUI 未运行，请先启动："
  echo "   cd /workspace/ComfyUI && python main.py --listen 0.0.0.0 --port 8188 --extra-model-paths-config /workspace/extra_model_paths.yaml &"
  exit 1
fi
echo "✅ ComfyUI 正在运行"

# 检查模型文件
echo ""
echo "检查模型文件..."
if [ ! -f "/workspace/models/checkpoints/ponyRealism_V23ULTRA.safetensors" ]; then
  echo "❌ Pony Realism checkpoint 不存在，请先运行 download_models.sh"
  exit 1
fi
if [ ! -f "/workspace/models/loras/AmateurStyle_v3_PONY_REALISM.safetensors" ]; then
  echo "❌ Pony Amateur LoRA 不存在，请先运行 download_models.sh"
  exit 1
fi
echo "✅ 模型文件就绪"

# 如果没有测试图片, 用 ComfyUI 生成一张纯色图
echo ""
echo "提交测试 prompt..."

# 用 workflow JSON 提交
WORKFLOW=$(cat /workspace/pony_i2i_api.json)
PAYLOAD="{\"prompt\": $WORKFLOW}"

RESPONSE=$(curl -s -X POST "$COMFY_URL/prompt" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

echo "Response: $RESPONSE"
echo ""
echo "🎯 检查 /workspace/ComfyUI/output/ 目录获取输出图片"
