#!/bin/bash
# ==============================================
# Pony i2i 一键配置脚本
#
# 功能: 自动检测 ComfyUI 路径, 配置模型路径,
#       下载缺失模型, 安装自定义节点和依赖
#
# 用法: bash /workspace/pony-i2i/start.sh
# ==============================================

SCRIPT_DIR="/workspace/pony-i2i"
MODELS_DIR="/workspace/models"

echo "=============================================="
echo "🚀 Pony i2i 一键配置"
echo "=============================================="

# ===== 0. 自动检测 ComfyUI 安装路径 =====
echo ""
echo "[0/5] 🔍 检测 ComfyUI 路径..."
COMFY_DIR=""
for path in /workspace/runpod-slim/ComfyUI /opt/comfyui-baked /workspace/ComfyUI /comfyui /root/ComfyUI /src/ComfyUI; do
    if [ -f "$path/main.py" ]; then
        COMFY_DIR="$path"
        break
    fi
done

if [ -z "$COMFY_DIR" ]; then
    echo "  ❌ 找不到 ComfyUI！已检查:"
    echo "     /workspace/runpod-slim/ComfyUI /opt/comfyui-baked /workspace/ComfyUI /comfyui /root/ComfyUI /src/ComfyUI"
    exit 1
fi

echo "  📍 ComfyUI 路径: $COMFY_DIR"
CUSTOM_NODES="$COMFY_DIR/custom_nodes"

# ===== 1. 复制 extra_model_paths.yaml =====
echo ""
echo "[1/5] 📋 复制模型路径配置文件..."
cp "$SCRIPT_DIR/extra_model_paths.yaml" "$COMFY_DIR/extra_model_paths.yaml"
echo "  ✅ extra_model_paths.yaml → $COMFY_DIR/"
echo "  ✅ ComfyUI 启动时将自动扫描 $MODELS_DIR/ 下的模型"
echo "     (checkpoints, loras, ipadapter, instantid, controlnet)"

# ===== 2. InsightFace 模型 (InstantID 节点直接读 ComfyUI/models/insightface，不走 extra_model_paths) =====
echo ""
echo "[2/5] 🧠 配置 InsightFace 模型..."

COMFY_INSIGHTFACE="$COMFY_DIR/models/insightface"
mkdir -p "$COMFY_INSIGHTFACE/models"

# antelopev2 模型（人脸检测/识别，所有换脸方案共用）
if [ -d "$COMFY_INSIGHTFACE/models/antelopev2" ] && [ -f "$COMFY_INSIGHTFACE/models/antelopev2/1k3d68.onnx" ]; then
    echo "  ✅ antelopev2 已存在"
else
    # 优先从网络卷复制
    if [ -d "$MODELS_DIR/insightface/models/antelopev2" ]; then
        echo "  📂 从网络卷复制 antelopev2..."
        cp -r "$MODELS_DIR/insightface/models/antelopev2" "$COMFY_INSIGHTFACE/models/"
        echo "  ✅ antelopev2 已复制"
    else
        echo "  📥 下载 antelopev2..."
        cd /tmp
        wget -q --show-progress -O antelopev2.zip \
          "https://huggingface.co/MonsterMMORPG/tools/resolve/main/antelopev2.zip"
        unzip -o antelopev2.zip -d "$COMFY_INSIGHTFACE/models/" 2>/dev/null
        rm -f antelopev2.zip
        # 修复 zip 双层嵌套: antelopev2/antelopev2/ → antelopev2/
        if [ -d "$COMFY_INSIGHTFACE/models/antelopev2/antelopev2" ]; then
            mv "$COMFY_INSIGHTFACE/models/antelopev2/antelopev2/"* "$COMFY_INSIGHTFACE/models/antelopev2/"
            rmdir "$COMFY_INSIGHTFACE/models/antelopev2/antelopev2" 2>/dev/null
        fi
        # 同时保存一份到网络卷
        mkdir -p "$MODELS_DIR/insightface/models/"
        cp -r "$COMFY_INSIGHTFACE/models/antelopev2" "$MODELS_DIR/insightface/models/"
        echo "  ✅ antelopev2 已下载并保存到网络卷"
    fi
fi

# inswapper_128.onnx（ReActor 用）
if [ -f "$COMFY_INSIGHTFACE/inswapper_128.onnx" ]; then
    echo "  ✅ inswapper_128.onnx 已存在"
else
    if [ -f "$MODELS_DIR/insightface/inswapper_128.onnx" ]; then
        echo "  📂 从网络卷复制 inswapper_128.onnx..."
        cp "$MODELS_DIR/insightface/inswapper_128.onnx" "$COMFY_INSIGHTFACE/"
        echo "  ✅ inswapper_128.onnx 已复制"
    else
        echo "  📥 下载 inswapper_128.onnx..."
        wget -q --show-progress -O "$COMFY_INSIGHTFACE/inswapper_128.onnx" \
          "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/inswapper_128.onnx"
        # 同时保存到网络卷
        mkdir -p "$MODELS_DIR/insightface/"
        cp "$COMFY_INSIGHTFACE/inswapper_128.onnx" "$MODELS_DIR/insightface/"
        echo "  ✅ inswapper_128.onnx 已下载并保存到网络卷"
    fi
fi

# ===== 3. 安装自定义节点 =====
echo ""
echo "[3/5] 🧩 安装自定义节点..."

if [ -d "$CUSTOM_NODES/ComfyUI_IPAdapter_plus" ]; then
    echo "  ✅ IPAdapter Plus 已存在"
else
    cd "$CUSTOM_NODES" && git clone --depth 1 -q https://github.com/cubiq/ComfyUI_IPAdapter_plus.git && echo "  ✅ IPAdapter Plus 已安装"
fi

if [ -d "$CUSTOM_NODES/ComfyUI-ReActor" ]; then
    echo "  ✅ ReActor 已存在"
else
    cd "$CUSTOM_NODES" && git clone --depth 1 -q https://github.com/Gourieff/ComfyUI-ReActor.git && \
    pip install -q -r "$CUSTOM_NODES/ComfyUI-ReActor/requirements.txt" 2>/dev/null && echo "  ✅ ReActor 已安装"
fi

if [ -d "$CUSTOM_NODES/ComfyUI_InstantID" ]; then
    echo "  ✅ InstantID 已存在"
else
    cd "$CUSTOM_NODES" && git clone --depth 1 -q https://github.com/cubiq/ComfyUI_InstantID.git && echo "  ✅ InstantID 已安装"
fi

# ===== 4. pip 依赖 =====
echo ""
echo "[4/5] 📦 检查 pip 依赖..."
python3 -c "import insightface" 2>/dev/null && echo "  ✅ insightface 已安装" || \
  (echo "  📥 安装 insightface..." && pip install -q insightface onnxruntime-gpu 2>&1 | tail -1 && echo "  ✅ insightface 已安装")

# ===== 5. 验证 =====
echo ""
echo "[5/5] 🔍 验证模型文件..."
echo ""

echo "  === checkpoints ==="
ls -lh "$MODELS_DIR/checkpoints/" 2>/dev/null || echo "  ⚠️ 目录不存在"
echo "  === loras ==="
ls -lh "$MODELS_DIR/loras/" 2>/dev/null || echo "  ⚠️ 目录不存在"
echo "  === ipadapter ==="
ls -lh "$MODELS_DIR/ipadapter/" 2>/dev/null || echo "  ⚠️ 目录不存在"
echo "  === instantid ==="
ls -lh "$MODELS_DIR/instantid/" 2>/dev/null || echo "  ⚠️ 目录不存在"
echo "  === controlnet ==="
ls -lh "$MODELS_DIR/controlnet/" 2>/dev/null || echo "  ⚠️ 目录不存在"
echo "  === insightface (ComfyUI 目录) ==="
ls "$COMFY_INSIGHTFACE/models/antelopev2/" 2>/dev/null || echo "  ⚠️ antelopev2 缺失"
ls -lh "$COMFY_INSIGHTFACE/inswapper_128.onnx" 2>/dev/null || echo "  ⚠️ inswapper_128.onnx 缺失"

echo ""
echo "=============================================="
echo "✅ 配置完毕！请手动重启 ComfyUI 使配置生效"
echo "=============================================="
