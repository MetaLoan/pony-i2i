# Pony i2i Worker

基于 **Pony Realism v2.3 ULTRA** (Checkpoint) + **Pony Amateur V3 CC & Grain** (LoRA) 的独立 img2img 工作流。

## 部署步骤

### 1. 在 RunPod GPU Pod 上下载模型

```bash
export CIVITAI_TOKEN=your_token_here
bash /workspace/download_models.sh
```

### 2. 启动 ComfyUI 测试

```bash
cd /workspace/ComfyUI
python main.py --listen 0.0.0.0 --port 8188 \
  --extra-model-paths-config /workspace/extra_model_paths.yaml &

# 本地测试
bash /workspace/test_local.sh
```

### 3. API 参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `image_url` | string | - | 输入图片 URL |
| `image_base64` | string | - | 或 base64 编码的图片 |
| `positive_prompt` | string | `""` | 用户提示词 (自动添加 Pony score + Amateur 触发词) |
| `negative_prompt` | string | `""` | 负面提示词 (自动添加 Pony 负面 score) |
| `denoise` | float | 0.5 | 去噪强度 (0.1-1.0, 越高变化越大) |
| `lora_strength` | float | 0.7 | Amateur LoRA 强度 (0.0-1.0) |
| `steps` | int | 30 | 采样步数 (10-80) |
| `cfg` | float | 6.5 | CFG Scale (1.0-15.0) |
| `seed` | int | random | 随机种子 |

### 4. 请求示例

```json
{
  "input": {
    "image_url": "https://example.com/photo.jpg",
    "positive_prompt": "female, portrait, 2000s nostalgia, flash",
    "denoise": 0.5,
    "lora_strength": 0.7
  }
}
```

### 5. 输出

返回 base64 编码的 PNG 图片，或上传到配置的存储服务。
