#!/bin/bash
# ==============================================
# Pony i2i 全自动启动脚本
# 每次 Pod 启动时运行，自动：
#   1. 安装/恢复自定义节点
#   2. 安装 pip 依赖
#   3. 建模型软链接
#   4. 启动 ComfyUI
#
# RunPod Template CMD: bash /workspace/pony-i2i/auto_start.sh
# ==============================================

COMFY_DIR="/opt/comfyui-baked"
CUSTOM_NODES="$COMFY_DIR/custom_nodes"
WORKSPACE_MODELS="/workspace/models"

echo "=============================================="
echo "🚀 Pony i2i Auto Start"
echo "=============================================="

# ===== 1. 安装自定义节点 (容器重启后会丢失) =====
echo ""
echo "📦 [1/4] 检查/安装自定义节点..."

if [ ! -d "$CUSTOM_NODES/ComfyUI_IPAdapter_plus" ]; then
  echo "  安装 ComfyUI_IPAdapter_plus..."
  cd $CUSTOM_NODES && git clone --depth 1 https://github.com/cubiq/ComfyUI_IPAdapter_plus.git 2>&1 | tail -1
else
  echo "  ✅ IPAdapter Plus"
fi

if [ ! -d "$CUSTOM_NODES/ComfyUI-ReActor" ] && [ ! -d "$CUSTOM_NODES/comfyui-reactor-node" ]; then
  echo "  安装 ComfyUI-ReActor..."
  cd $CUSTOM_NODES && git clone --depth 1 https://github.com/Gourieff/ComfyUI-ReActor.git 2>&1 | tail -1
  pip install -q -r $CUSTOM_NODES/ComfyUI-ReActor/requirements.txt 2>/dev/null
else
  echo "  ✅ ReActor"
fi

if [ ! -d "$CUSTOM_NODES/ComfyUI_InstantID" ]; then
  echo "  安装 ComfyUI_InstantID..."
  cd $CUSTOM_NODES && git clone --depth 1 https://github.com/cubiq/ComfyUI_InstantID.git 2>&1 | tail -1
else
  echo "  ✅ InstantID"
fi

# ===== 2. 安装 pip 依赖 =====
echo ""
echo "📦 [2/4] 检查/安装 pip 依赖..."

python3 -c "import insightface" 2>/dev/null
if [ $? -ne 0 ]; then
  echo "  安装 insightface + onnxruntime-gpu..."
  pip install -q insightface onnxruntime-gpu 2>&1 | tail -3
else
  echo "  ✅ insightface 已安装"
fi

# ===== 3. 建模型软链接 =====
echo ""
echo "🔗 [3/4] 建立模型软链接..."

# Checkpoints
for f in $WORKSPACE_MODELS/checkpoints/*.safetensors; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  target="$COMFY_DIR/models/checkpoints/$name"
  if [ ! -e "$target" ]; then
    ln -sf "$f" "$target"
    echo "  ✅ checkpoint: $name"
  fi
done

# LoRAs
for f in $WORKSPACE_MODELS/loras/*.safetensors; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  target="$COMFY_DIR/models/loras/$name"
  if [ ! -e "$target" ]; then
    ln -sf "$f" "$target"
    echo "  ✅ lora: $name"
  fi
done

# IPAdapter 模型 (如果在 workspace 上)
if [ -d "$WORKSPACE_MODELS/ipadapter" ]; then
  mkdir -p "$COMFY_DIR/models/ipadapter"
  for f in $WORKSPACE_MODELS/ipadapter/*; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    target="$COMFY_DIR/models/ipadapter/$name"
    [ -e "$target" ] || ln -sf "$f" "$target" && echo "  ✅ ipadapter: $name"
  done
fi

# InsightFace 模型
if [ -d "$WORKSPACE_MODELS/insightface" ]; then
  mkdir -p "$COMFY_DIR/models/insightface"
  cp -rn $WORKSPACE_MODELS/insightface/* "$COMFY_DIR/models/insightface/" 2>/dev/null
  echo "  ✅ insightface 模型"
fi

# InstantID 模型
if [ -d "$WORKSPACE_MODELS/instantid" ]; then
  mkdir -p "$COMFY_DIR/models/instantid"
  for f in $WORKSPACE_MODELS/instantid/*; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    target="$COMFY_DIR/models/instantid/$name"
    [ -e "$target" ] || ln -sf "$f" "$target" && echo "  ✅ instantid: $name"
  done
fi

# ControlNet 模型
if [ -d "$WORKSPACE_MODELS/controlnet" ]; then
  mkdir -p "$COMFY_DIR/models/controlnet"
  for f in $WORKSPACE_MODELS/controlnet/*; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    target="$COMFY_DIR/models/controlnet/$name"
    [ -e "$target" ] || ln -sf "$f" "$target" && echo "  ✅ controlnet: $name"
  done
fi

echo "  模型统计: checkpoints=$(ls $COMFY_DIR/models/checkpoints/*.safetensors 2>/dev/null | wc -l), loras=$(ls $COMFY_DIR/models/loras/*.safetensors 2>/dev/null | wc -l)"

# ===== 4. 启动 ComfyUI =====
echo ""
echo "🚀 [4/4] 启动 ComfyUI..."
pkill -f "main.py" 2>/dev/null
sleep 2

cd $COMFY_DIR && python3 main.py --listen 0.0.0.0 --port 8188 &
COMFY_PID=$!

for i in $(seq 1 60); do
  if curl -s http://127.0.0.1:8188/system_stats > /dev/null 2>&1; then
    echo "  ✅ ComfyUI 已启动 (PID: $COMFY_PID)"
    break
  fi
  sleep 2
done

echo ""
echo "=============================================="
echo "✅ 启动完毕！"
echo "=============================================="
