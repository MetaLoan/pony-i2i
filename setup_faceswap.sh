#!/bin/bash
# ==============================================
# 换脸模型下载脚本 (下载到 /workspace 网络卷, 永久持久化)
# 只需运行一次！之后 auto_start.sh 会自动软链到 ComfyUI
# ==============================================

MODELS_DIR="/workspace/models"

echo "🚀 下载换脸模型到 Network Volume"
echo "目标: $MODELS_DIR"
echo ""

# ===== InsightFace (所有方案共用) =====
echo "📥 [1/5] InsightFace antelopev2..."

INSIGHTFACE_DIR="$MODELS_DIR/insightface/models/antelopev2"
mkdir -p "$INSIGHTFACE_DIR"

if [ ! -f "$INSIGHTFACE_DIR/1k3d68.onnx" ]; then
  cd /tmp
  wget -q --show-progress -O antelopev2.zip \
    "https://huggingface.co/MonsterMMORPG/tools/resolve/main/antelopev2.zip"
  unzip -o antelopev2.zip -d "$MODELS_DIR/insightface/models/" 2>/dev/null
  rm -f antelopev2.zip
else
  echo "  ✅ 已存在"
fi

# ===== Inswapper (ReActor用) =====
echo ""
echo "📥 [2/5] inswapper_128.onnx (ReActor)..."

mkdir -p "$MODELS_DIR/insightface"
if [ ! -f "$MODELS_DIR/insightface/inswapper_128.onnx" ]; then
  wget -q --show-progress -O "$MODELS_DIR/insightface/inswapper_128.onnx" \
    "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/inswapper_128.onnx"
else
  echo "  ✅ 已存在"
fi

# ===== IPAdapter FaceID =====
echo ""
echo "📥 [3/5] IPAdapter FaceID Plus V2..."

mkdir -p "$MODELS_DIR/ipadapter"
if [ ! -f "$MODELS_DIR/ipadapter/ip-adapter-faceid-plusv2_sdxl.bin" ]; then
  wget -q --show-progress -O "$MODELS_DIR/ipadapter/ip-adapter-faceid-plusv2_sdxl.bin" \
    "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin"
else
  echo "  ✅ 已存在"
fi

if [ ! -f "$MODELS_DIR/loras/ip-adapter-faceid-plusv2_sdxl_lora.safetensors" ]; then
  wget -q --show-progress -O "$MODELS_DIR/loras/ip-adapter-faceid-plusv2_sdxl_lora.safetensors" \
    "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl_lora.safetensors"
else
  echo "  ✅ FaceID LoRA 已存在"
fi

# ===== InstantID =====
echo ""
echo "📥 [4/5] InstantID ip-adapter..."

mkdir -p "$MODELS_DIR/instantid"
if [ ! -f "$MODELS_DIR/instantid/ip-adapter.bin" ]; then
  wget -q --show-progress -O "$MODELS_DIR/instantid/ip-adapter.bin" \
    "https://huggingface.co/InstantX/InstantID/resolve/main/ip-adapter.bin"
else
  echo "  ✅ 已存在"
fi

echo ""
echo "📥 [5/5] InstantID ControlNet..."

mkdir -p "$MODELS_DIR/controlnet"
if [ ! -f "$MODELS_DIR/controlnet/instantid_diffusion_pytorch_model.safetensors" ]; then
  wget -q --show-progress -O "$MODELS_DIR/controlnet/instantid_diffusion_pytorch_model.safetensors" \
    "https://huggingface.co/InstantX/InstantID/resolve/main/ControlNetModel/diffusion_pytorch_model.safetensors"
else
  echo "  ✅ 已存在"
fi

echo ""
echo "🔍 验证:"
echo "=== insightface ==="
ls $MODELS_DIR/insightface/models/antelopev2/ 2>/dev/null
ls -lh $MODELS_DIR/insightface/inswapper_128.onnx 2>/dev/null
echo "=== ipadapter ==="
ls -lh $MODELS_DIR/ipadapter/ 2>/dev/null
echo "=== instantid ==="
ls -lh $MODELS_DIR/instantid/ 2>/dev/null
echo "=== controlnet ==="
ls -lh $MODELS_DIR/controlnet/ 2>/dev/null
echo ""
echo "✅ 所有换脸模型下载完毕！"
echo "   运行 auto_start.sh 会自动软链到 ComfyUI"
