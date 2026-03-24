#!/bin/bash
# ==============================================
# Pony i2i 启动脚本 (根源方案, 无软链接)
#
# 原理: 把 extra_model_paths.yaml 复制到 ComfyUI 目录,
#       ComfyUI 启动时自动读取, 直接扫描 /workspace/models/
#       不需要任何软链接!
#
# RunPod Template → Container Start Command:
#   bash /workspace/pony-i2i/auto_start.sh
# ==============================================

COMFY_DIR="/opt/comfyui-baked"
CUSTOM_NODES="$COMFY_DIR/custom_nodes"

echo "=============================================="
echo "🚀 Pony i2i 启动"
echo "=============================================="

# ===== 0. 杀掉已有的 ComfyUI 进程 =====
echo "[0/4] 清理已有进程..."
pkill -f "main.py" 2>/dev/null
fuser -k 8188/tcp 2>/dev/null
sleep 2
echo "  ✅ 端口 8188 已释放"

# ===== 1. 复制 extra_model_paths.yaml =====
echo "[1/4] 配置模型路径..."
cp /workspace/pony-i2i/extra_model_paths.yaml $COMFY_DIR/extra_model_paths.yaml
echo "  ✅ ComfyUI 将自动扫描 /workspace/models/"

# ===== 2. 安装自定义节点 =====
echo "[2/4] 安装自定义节点..."

[ -d "$CUSTOM_NODES/ComfyUI_IPAdapter_plus" ] || \
  (cd $CUSTOM_NODES && git clone --depth 1 -q https://github.com/cubiq/ComfyUI_IPAdapter_plus.git && echo "  ✅ IPAdapter Plus 已安装")

[ -d "$CUSTOM_NODES/ComfyUI-ReActor" ] || \
  (cd $CUSTOM_NODES && git clone --depth 1 -q https://github.com/Gourieff/ComfyUI-ReActor.git && \
   pip install -q -r $CUSTOM_NODES/ComfyUI-ReActor/requirements.txt 2>/dev/null && echo "  ✅ ReActor 已安装")

[ -d "$CUSTOM_NODES/ComfyUI_InstantID" ] || \
  (cd $CUSTOM_NODES && git clone --depth 1 -q https://github.com/cubiq/ComfyUI_InstantID.git && echo "  ✅ InstantID 已安装")

# ===== 3. pip 依赖 =====
echo "[3/4] 检查 pip 依赖..."
python3 -c "import insightface" 2>/dev/null || \
  (echo "  安装 insightface..." && pip install -q insightface onnxruntime-gpu 2>&1 | tail -1)

# ===== 4. 启动 ComfyUI =====
echo "[4/4] 启动 ComfyUI..."
echo "=============================================="

cd $COMFY_DIR
exec python3 main.py --listen 0.0.0.0 --port 8188
