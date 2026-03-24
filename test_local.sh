#!/bin/bash
# 快速测试脚本 - 在 RunPod GPU Pod 上运行
# 使用方法: bash test_local.sh

COMFY_DIR="/opt/comfyui-baked"
COMFY_URL="http://127.0.0.1:8188"

echo "🧪 Pony i2i 本地测试"

# 检查模型文件
echo "检查模型文件..."
ls -lh /workspace/models/checkpoints/ponyRealism_V23ULTRA.safetensors 2>/dev/null || echo "❌ Checkpoint 不存在"
ls -lh /workspace/models/loras/AmateurStyle_v3_PONY_REALISM.safetensors 2>/dev/null || echo "❌ LoRA 不存在"

# 启动 ComfyUI
echo ""
echo "启动 ComfyUI..."
cd $COMFY_DIR
python3 main.py --listen 0.0.0.0 --port 8188 \
  --extra-model-paths-config /workspace/pony-i2i/extra_model_paths.yaml &
COMFY_PID=$!

# 等待 ComfyUI 启动
echo "等待 ComfyUI 启动..."
for i in $(seq 1 60); do
  if curl -s "$COMFY_URL/system_stats" > /dev/null 2>&1; then
    echo "✅ ComfyUI 已启动"
    break
  fi
  sleep 2
  echo "  等待中... (${i})"
done

# 检查可用模型
echo ""
echo "检查 ComfyUI 加载的模型..."
curl -s "$COMFY_URL/object_info/CheckpointLoaderSimple" | python3 -c "
import sys, json
data = json.load(sys.stdin)
ckpts = data.get('CheckpointLoaderSimple', {}).get('input', {}).get('required', {}).get('ckpt_name', [[]])[0]
print(f'可用 Checkpoints ({len(ckpts)}):')
for c in ckpts: print(f'  - {c}')
" 2>/dev/null || echo "⚠️ 无法获取模型列表"

echo ""
echo "🎯 ComfyUI 运行中 (PID: $COMFY_PID)"
echo "   按 Ctrl+C 停止"
wait $COMFY_PID
