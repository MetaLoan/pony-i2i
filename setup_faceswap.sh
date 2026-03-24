#!/bin/bash
# ==============================================
# Pony t2i + Face Swap 全套安装脚本
# 在 RunPod Pod 上运行: bash setup_faceswap.sh
# ==============================================

COMFY_DIR="/opt/comfyui-baked"
MODELS_DIR="$COMFY_DIR/models"
CUSTOM_NODES="$COMFY_DIR/custom_nodes"

echo "🚀 Pony t2i + Face Swap 全套安装"
echo "ComfyUI: $COMFY_DIR"
echo ""

# ===== 1. 安装自定义节点 =====
echo "📦 [1/3] 安装自定义节点..."

# IPAdapter Plus (含 FaceID 支持)
if [ ! -d "$CUSTOM_NODES/ComfyUI_IPAdapter_plus" ]; then
  echo "  安装 ComfyUI_IPAdapter_plus..."
  cd $CUSTOM_NODES
  git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus.git
else
  echo "  ✅ ComfyUI_IPAdapter_plus 已存在"
fi

# ReActor (换脸) - 使用 Gourieff 官方仓库
if [ ! -d "$CUSTOM_NODES/comfyui-reactor-node" ] && [ ! -d "$CUSTOM_NODES/ComfyUI-ReActor" ]; then
  echo "  安装 ComfyUI-ReActor..."
  cd $CUSTOM_NODES
  git clone https://github.com/Gourieff/ComfyUI-ReActor.git
  cd ComfyUI-ReActor
  pip install -r requirements.txt 2>/dev/null
  pip install insightface onnxruntime-gpu 2>/dev/null
else
  echo "  ✅ ReActor 已存在"
fi

# InstantID
if [ ! -d "$CUSTOM_NODES/ComfyUI_InstantID" ] && [ ! -d "$CUSTOM_NODES/ComfyUI-InstantID" ]; then
  echo "  安装 ComfyUI_InstantID..."
  cd $CUSTOM_NODES
  git clone https://github.com/cubiq/ComfyUI_InstantID.git
else
  echo "  ✅ ComfyUI-InstantID 已存在"
fi

# 安装 insightface (所有方案都需要)
echo "  安装 insightface + onnxruntime..."
pip install insightface onnxruntime-gpu 2>/dev/null

echo ""

# ===== 2. 下载 InsightFace 模型 (所有方案共用) =====
echo "📥 [2/3] 下载 InsightFace 模型..."

INSIGHTFACE_DIR="$MODELS_DIR/insightface/models/antelopev2"
mkdir -p "$INSIGHTFACE_DIR"

if [ ! -f "$INSIGHTFACE_DIR/1k3d68.onnx" ]; then
  echo "  下载 antelopev2 模型包..."
  cd /tmp
  wget -q --show-progress -O antelopev2.zip \
    "https://huggingface.co/MonsterMMORPG/tools/resolve/main/antelopev2.zip"
  unzip -o antelopev2.zip -d "$MODELS_DIR/insightface/models/" 2>/dev/null
  rm -f antelopev2.zip
else
  echo "  ✅ antelopev2 已存在"
fi

# ReActor 的 inswapper 模型
INSWAPPER_DIR="$MODELS_DIR/insightface"
if [ ! -f "$INSWAPPER_DIR/inswapper_128.onnx" ]; then
  echo "  下载 inswapper_128.onnx (ReActor用)..."
  wget -q --show-progress -O "$INSWAPPER_DIR/inswapper_128.onnx" \
    "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/inswapper_128.onnx"
else
  echo "  ✅ inswapper_128.onnx 已存在"
fi

echo ""

# ===== 3. 下载各方案专用模型 =====
echo "📥 [3/3] 下载方案专用模型..."

# --- 方案1: IPAdapter FaceID ---
echo ""
echo "  --- 方案1: IPAdapter FaceID Plus V2 ---"

IPADAPTER_DIR="$MODELS_DIR/ipadapter"
mkdir -p "$IPADAPTER_DIR"

if [ ! -f "$IPADAPTER_DIR/ip-adapter-faceid-plusv2_sdxl.bin" ]; then
  echo "  下载 ip-adapter-faceid-plusv2_sdxl.bin (~1.3GB)..."
  wget -q --show-progress -O "$IPADAPTER_DIR/ip-adapter-faceid-plusv2_sdxl.bin" \
    "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin"
else
  echo "  ✅ ip-adapter-faceid-plusv2_sdxl.bin 已存在"
fi

# FaceID 配套 LoRA
LORAS_DIR="$MODELS_DIR/loras"
if [ ! -f "$LORAS_DIR/ip-adapter-faceid-plusv2_sdxl_lora.safetensors" ]; then
  echo "  下载 ip-adapter-faceid-plusv2_sdxl_lora.safetensors (~371MB)..."
  wget -q --show-progress -O "$LORAS_DIR/ip-adapter-faceid-plusv2_sdxl_lora.safetensors" \
    "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl_lora.safetensors"
else
  echo "  ✅ ip-adapter-faceid-plusv2_sdxl_lora 已存在"
fi

# --- 方案3: InstantID ---
echo ""
echo "  --- 方案3: InstantID ---"

INSTANTID_DIR="$MODELS_DIR/instantid"
mkdir -p "$INSTANTID_DIR"

if [ ! -f "$INSTANTID_DIR/ip-adapter.bin" ]; then
  echo "  下载 InstantID ip-adapter.bin (~1.7GB)..."
  wget -q --show-progress -O "$INSTANTID_DIR/ip-adapter.bin" \
    "https://huggingface.co/InstantX/InstantID/resolve/main/ip-adapter.bin"
else
  echo "  ✅ InstantID ip-adapter.bin 已存在"
fi

CONTROLNET_DIR="$MODELS_DIR/controlnet"
mkdir -p "$CONTROLNET_DIR"

if [ ! -f "$CONTROLNET_DIR/instantid_diffusion_pytorch_model.safetensors" ]; then
  echo "  下载 InstantID ControlNet (~1.7GB)..."
  wget -q --show-progress -O "$CONTROLNET_DIR/instantid_diffusion_pytorch_model.safetensors" \
    "https://huggingface.co/InstantX/InstantID/resolve/main/ControlNetModel/diffusion_pytorch_model.safetensors"
else
  echo "  ✅ InstantID ControlNet 已存在"
fi

echo ""
echo "🔍 验证所有文件："
echo "=== InsightFace ==="
ls -lh $MODELS_DIR/insightface/inswapper_128.onnx 2>/dev/null
ls $MODELS_DIR/insightface/models/antelopev2/ 2>/dev/null
echo "=== IPAdapter FaceID ==="
ls -lh $IPADAPTER_DIR/ 2>/dev/null
echo "=== IPAdapter FaceID LoRA ==="
ls -lh $LORAS_DIR/ip-adapter-faceid-plusv2_sdxl_lora.safetensors 2>/dev/null
echo "=== InstantID ==="
ls -lh $INSTANTID_DIR/ 2>/dev/null
ls -lh $CONTROLNET_DIR/instantid_* 2>/dev/null
echo ""
echo "=== 别忘了 Pony 模型(应该已经有了) ==="
ls -lh $MODELS_DIR/checkpoints/ponyRealism_V23ULTRA.safetensors 2>/dev/null || \
ls -lh /workspace/models/checkpoints/ponyRealism_V23ULTRA.safetensors 2>/dev/null || \
echo "❌ Pony Realism checkpoint 不存在！请先软链"
ls -lh $MODELS_DIR/loras/AmateurStyle_v3_PONY_REALISM.safetensors 2>/dev/null || \
ls -lh /workspace/models/loras/AmateurStyle_v3_PONY_REALISM.safetensors 2>/dev/null || \
echo "❌ Pony Amateur LoRA 不存在！请先软链"

echo ""
echo "✅ 全部安装完毕！重启 ComfyUI 后生效："
echo "   pkill -f main.py; sleep 2"
echo "   cd $COMFY_DIR && python3 main.py --listen 0.0.0.0 --port 8188 &"
