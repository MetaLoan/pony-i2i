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

# 自动检测 ComfyUI 安装路径
COMFY_DIR=""
for path in /opt/comfyui-baked /workspace/ComfyUI /comfyui /root/ComfyUI /src/ComfyUI; do
    if [ -f "$path/main.py" ]; then
        COMFY_DIR="$path"
        break
    fi
done

if [ -z "$COMFY_DIR" ]; then
    echo "❌ 找不到 ComfyUI 安装目录！请检查 Pod 模板"
    echo "   已检查: /opt/comfyui-baked /workspace/ComfyUI /comfyui /root/ComfyUI /src/ComfyUI"
    exit 1
fi

echo "📍 ComfyUI 路径: $COMFY_DIR"
CUSTOM_NODES="$COMFY_DIR/custom_nodes"

echo "=============================================="
echo "🚀 Pony i2i 环境配置"
echo "=============================================="

# ===== 1. 复制 extra_model_paths.yaml =====
echo "[1/3] 📋 复制模型路径配置文件..."
cp /workspace/pony-i2i/extra_model_paths.yaml $COMFY_DIR/extra_model_paths.yaml
echo "  ✅ 已将 extra_model_paths.yaml 复制到 $COMFY_DIR/"
echo "  ✅ ComfyUI 启动时将自动扫描 /workspace/models/ 下的所有模型"

# ===== 2. 安装自定义节点 =====
echo "[2/3] 安装自定义节点..."

[ -d "$CUSTOM_NODES/ComfyUI_IPAdapter_plus" ] || \
  (cd $CUSTOM_NODES && git clone --depth 1 -q https://github.com/cubiq/ComfyUI_IPAdapter_plus.git && echo "  ✅ IPAdapter Plus 已安装")

[ -d "$CUSTOM_NODES/ComfyUI-ReActor" ] || \
  (cd $CUSTOM_NODES && git clone --depth 1 -q https://github.com/Gourieff/ComfyUI-ReActor.git && \
   pip install -q -r $CUSTOM_NODES/ComfyUI-ReActor/requirements.txt 2>/dev/null && echo "  ✅ ReActor 已安装")

[ -d "$CUSTOM_NODES/ComfyUI_InstantID" ] || \
  (cd $CUSTOM_NODES && git clone --depth 1 -q https://github.com/cubiq/ComfyUI_InstantID.git && echo "  ✅ InstantID 已安装")

# ===== 3. pip 依赖 =====
echo "[3/3] 检查 pip 依赖..."
python3 -c "import insightface" 2>/dev/null || \
  (echo "  安装 insightface..." && pip install -q insightface onnxruntime-gpu 2>&1 | tail -1)

echo "=============================================="
echo "✅ 配置完毕！请手动重启 ComfyUI 使配置生效"
echo "=============================================="
