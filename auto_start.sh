#!/bin/bash
# ==============================================
# Pony i2i 自动启动脚本
# 放在 /workspace/ (网络卷, 永久持久化)
# 每次 Pod 启动时运行，自动建软链 + 启 ComfyUI
#
# 用法: 在 RunPod Pod Template 的 Docker CMD 设置为:
#   bash /workspace/pony-i2i/auto_start.sh
# 或者手动运行: bash /workspace/pony-i2i/auto_start.sh
# ==============================================

COMFY_DIR="/opt/comfyui-baked"
WORKSPACE_MODELS="/workspace/models"

echo "🔗 [1/3] 建立模型软链接..."

# Checkpoint 软链
for f in $WORKSPACE_MODELS/checkpoints/*.safetensors; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  target="$COMFY_DIR/models/checkpoints/$name"
  if [ ! -e "$target" ]; then
    ln -sf "$f" "$target"
    echo "  ✅ 链接: $name → checkpoints/"
  else
    echo "  ⏭  已存在: $name"
  fi
done

# LoRA 软链
for f in $WORKSPACE_MODELS/loras/*.safetensors; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  target="$COMFY_DIR/models/loras/$name"
  if [ ! -e "$target" ]; then
    ln -sf "$f" "$target"
    echo "  ✅ 链接: $name → loras/"
  else
    echo "  ⏭  已存在: $name"
  fi
done

echo ""
echo "🔍 [2/3] 验证模型..."
echo "  checkpoints: $(ls $COMFY_DIR/models/checkpoints/*.safetensors 2>/dev/null | wc -l) 个"
echo "  loras: $(ls $COMFY_DIR/models/loras/*.safetensors 2>/dev/null | wc -l) 个"

echo ""
echo "🚀 [3/3] 重启 ComfyUI..."
pkill -f "main.py" 2>/dev/null
sleep 2

cd $COMFY_DIR && python3 main.py --listen 0.0.0.0 --port 8188 &
COMFY_PID=$!

# 等待 ComfyUI 启动
echo "  等待 ComfyUI 启动..."
for i in $(seq 1 60); do
  if curl -s http://127.0.0.1:8188/system_stats > /dev/null 2>&1; then
    echo "  ✅ ComfyUI 已启动 (PID: $COMFY_PID)"
    break
  fi
  sleep 2
done

# 验证模型是否被 ComfyUI 识别
echo ""
echo "📋 ComfyUI 已加载的 Checkpoints:"
curl -s http://127.0.0.1:8188/object_info/CheckpointLoaderSimple 2>/dev/null | \
  python3 -c "import sys,json; [print(f'  - {c}') for c in json.load(sys.stdin).get('CheckpointLoaderSimple',{}).get('input',{}).get('required',{}).get('ckpt_name',[[]])[0]]" 2>/dev/null || echo "  ⚠️ 无法获取"

echo ""
echo "✅ 启动完毕！ComfyUI 运行中。"
echo "   Ctrl+C 不会停止 ComfyUI (后台运行)"
