import os
import json
import time
import base64
import urllib.request
import urllib.error
import uuid
import random
import requests
import runpod
import websocket
import subprocess
import threading

COMFY_URL = "127.0.0.1:8188"
API_JSON_PATH = "/workspace/pony-i2i/pony_i2i_api.json"
COMFY_DIR = "/opt/comfyui-baked"
OUTPUT_DIR = f"{COMFY_DIR}/output"
INPUT_DIR = f"{COMFY_DIR}/input"


def start_comfyui():
    print("Starting ComfyUI server...", flush=True)
    process = subprocess.Popen(
        ["python3", "-u", "main.py", "--listen", "0.0.0.0", "--port", "8188",
         "--extra-model-paths-config", "/workspace/pony-i2i/extra_model_paths.yaml"],
        cwd=COMFY_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    )

    def stream_logs():
        for line in process.stdout:
            print(f"[ComfyUI] {line.strip()}", flush=True)
    threading.Thread(target=stream_logs, daemon=True).start()

    max_wait = 300
    start_time = time.time()
    while True:
        elapsed = time.time() - start_time
        if elapsed > max_wait:
            print(f"FATAL: ComfyUI did not start within {max_wait}s!", flush=True)
            break
        if process.poll() is not None:
            print(f"FATAL: ComfyUI process died with code {process.returncode}!", flush=True)
            break
        try:
            req = urllib.request.Request(f"http://{COMFY_URL}/system_stats")
            urllib.request.urlopen(req, timeout=2)
            print(f"ComfyUI ready! (took {elapsed:.0f}s)", flush=True)
            return True
        except urllib.error.URLError:
            time.sleep(1)
            if int(elapsed) % 10 == 0:
                print(f"Waiting for ComfyUI... ({elapsed:.0f}s)", flush=True)
    return False


def queue_prompt(workflow):
    client_id = str(uuid.uuid4())
    payload = {"prompt": workflow, "client_id": client_id}
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(
        f"http://{COMFY_URL}/prompt",
        data=data,
        headers={'Content-Type': 'application/json'}
    )
    try:
        with urllib.request.urlopen(req) as response:
            res = json.loads(response.read())
            print(f"Prompt queued: {res}", flush=True)
            return res.get('prompt_id'), client_id
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8', errors='replace')
        print(f"HTTP Error {e.code}: {error_body}", flush=True)
        return None, error_body
    except urllib.error.URLError as e:
        print(f"URL Error: {e}", flush=True)
        return None, str(e)


def wait_for_execution(client_id, prompt_id, timeout=300):
    ws = websocket.WebSocket()
    ws.settimeout(timeout)
    ws.connect(f"ws://{COMFY_URL}/ws?clientId={client_id}")
    try:
        while True:
            out = ws.recv()
            if isinstance(out, str):
                msg = json.loads(out)
                msg_type = msg.get('type')
                if msg_type == 'executing':
                    data = msg.get('data', {})
                    node = data.get('node')
                    if node:
                        print(f"[Progress] Node: {node}", flush=True)
                    if node is None and data.get('prompt_id') == prompt_id:
                        print("Execution finished!", flush=True)
                        break
                elif msg_type == 'execution_error':
                    print(f"[ERROR] {msg.get('data', {})}", flush=True)
                    break
    except websocket.WebSocketTimeoutException:
        print(f"WebSocket timeout after {timeout}s", flush=True)
    finally:
        ws.close()


def fetch_history(prompt_id):
    req = urllib.request.Request(f"http://{COMFY_URL}/history/{prompt_id}")
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read())


def download_input_image(image_url, filename="serverless_input.png"):
    os.makedirs(INPUT_DIR, exist_ok=True)
    filepath = os.path.join(INPUT_DIR, filename)
    print(f"Downloading input image from {image_url}...", flush=True)
    try:
        req = urllib.request.Request(image_url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=30) as resp:
            with open(filepath, 'wb') as f:
                f.write(resp.read())
        size = os.path.getsize(filepath)
        print(f"Input image saved: {filepath} ({size} bytes)", flush=True)
        return filename
    except Exception as e:
        print(f"Failed to download input image: {e}", flush=True)
        return None


def save_base64_image(b64_string, filename="serverless_input.png"):
    os.makedirs(INPUT_DIR, exist_ok=True)
    filepath = os.path.join(INPUT_DIR, filename)
    if ',' in b64_string:
        b64_string = b64_string.split(',', 1)[1]
    with open(filepath, 'wb') as f:
        f.write(base64.b64decode(b64_string))
    size = os.path.getsize(filepath)
    print(f"Base64 image saved: {filepath} ({size} bytes)", flush=True)
    return filename


def process_job(job):
    job_input = job.get('input', {})
    print(f"Received payload: {json.dumps(job_input, ensure_ascii=False)[:500]}", flush=True)

    # Extract parameters
    pos_prompt = job_input.get('positive_prompt', '')
    neg_prompt = job_input.get('negative_prompt', '')
    denoise = job_input.get('denoise', 0.5)
    lora_strength = job_input.get('lora_strength', 0.7)
    steps = job_input.get('steps', 30)
    cfg = job_input.get('cfg', 6.5)
    seed = job_input.get('seed', random.randint(1, 2**53))
    image_url = job_input.get('image_url', '')
    image_base64 = job_input.get('image_base64', '')

    # Clamp values
    denoise = max(0.1, min(1.0, denoise))
    lora_strength = max(0.0, min(1.0, lora_strength))
    steps = max(10, min(80, steps))
    cfg = max(1.0, min(15.0, cfg))

    # Handle input image
    input_filename = None
    if image_base64:
        input_filename = save_base64_image(image_base64)
    elif image_url:
        input_filename = download_input_image(image_url)

    if not input_filename:
        return {"error": "No input image. Supply 'image_url' or 'image_base64'."}

    # Build positive prompt with Pony quality tags and Amateur trigger words
    pony_prefix = "score_9, score_8_up, score_7_up"
    amateur_triggers = "photo, film grain, grainy, amateur"
    if pos_prompt:
        full_pos = f"{pony_prefix}, {amateur_triggers}, {pos_prompt}"
    else:
        full_pos = f"{pony_prefix}, {amateur_triggers}, masterpiece, high quality"

    # Build negative prompt with Pony negative tags
    pony_neg = "score_4, score_5, score_6"
    if neg_prompt:
        full_neg = f"{pony_neg}, {neg_prompt}"
    else:
        full_neg = f"{pony_neg}, ugly, blurry, low quality, deformed, bad anatomy"

    # Load workflow template
    with open(API_JSON_PATH, 'r', encoding='utf-8') as f:
        graph = json.load(f)

    # Inject parameters
    graph["2"]["inputs"]["strength_model"] = lora_strength
    graph["2"]["inputs"]["strength_clip"] = lora_strength
    graph["3"]["inputs"]["text"] = full_pos
    graph["4"]["inputs"]["text"] = full_neg
    graph["5"]["inputs"]["image"] = input_filename
    graph["7"]["inputs"]["seed"] = seed
    graph["7"]["inputs"]["steps"] = steps
    graph["7"]["inputs"]["cfg"] = cfg
    graph["7"]["inputs"]["denoise"] = denoise

    # Remove upload key if present
    if "upload" in graph["5"]["inputs"]:
        del graph["5"]["inputs"]["upload"]

    # Submit to ComfyUI
    prompt_id, client_id = queue_prompt(graph)
    if not prompt_id:
        return {"error": f"ComfyUI rejected workflow: {client_id}"}

    print(f"Queued: {prompt_id}. Waiting...", flush=True)
    wait_for_execution(client_id, prompt_id)

    # Collect outputs
    history = fetch_history(prompt_id)
    prompt_output = history.get(prompt_id, {})
    outputs = prompt_output.get('outputs', {})

    image_files = []
    for node_id in outputs:
        node_out = outputs[node_id]
        if "images" in node_out:
            for img_info in node_out["images"]:
                fname = img_info.get("filename", "")
                subfolder = img_info.get("subfolder", "")
                filepath = os.path.join(OUTPUT_DIR, subfolder, fname)
                if os.path.exists(filepath):
                    image_files.append(filepath)

    # Fallback scan
    if not image_files and os.path.exists(OUTPUT_DIR):
        for f in sorted(os.listdir(OUTPUT_DIR)):
            if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp')):
                image_files.append(os.path.join(OUTPUT_DIR, f))

    # Encode output images as base64
    encoded_images = []
    image_url_result = None
    upload_url = os.environ.get("IMAGE_UPLOAD_URL", "")
    upload_token = os.environ.get("IMAGE_UPLOAD_TOKEN", "")

    for img_path in image_files:
        if upload_url:
            try:
                with open(img_path, "rb") as f:
                    headers = {}
                    if upload_token:
                        headers["Authorization"] = f"Bearer {upload_token}"
                    resp = requests.post(
                        upload_url,
                        files={"file": (os.path.basename(img_path), f, "image/png")},
                        headers=headers,
                        timeout=60
                    )
                    if resp.status_code == 200:
                        image_url_result = resp.json().get("url", "")
                        print(f"Uploaded to: {image_url_result}", flush=True)
            except Exception as e:
                print(f"Upload error: {e}", flush=True)

        with open(img_path, "rb") as f:
            encoded_str = base64.b64encode(f.read()).decode('utf-8')
            encoded_images.append(f"data:image/png;base64,{encoded_str}")

    # Cleanup
    for img_path in image_files:
        if os.path.exists(img_path):
            os.remove(img_path)
    input_path = os.path.join(INPUT_DIR, input_filename)
    if os.path.exists(input_path):
        os.remove(input_path)

    result = {
        "status": "success",
        "parameters_used": {
            "positive_prompt": full_pos,
            "negative_prompt": full_neg,
            "denoise": denoise,
            "lora_strength": lora_strength,
            "steps": steps,
            "cfg": cfg,
            "seed": seed
        },
        "image_count": len(encoded_images),
    }

    if image_url_result:
        result["image_url"] = image_url_result
    if encoded_images:
        result["image_base64_array"] = encoded_images

    return result


if __name__ == "__main__":
    print("=" * 60, flush=True)
    print("Pony i2i Worker - Pony Realism + Pony Amateur", flush=True)
    print("=" * 60, flush=True)

    ok = start_comfyui()
    if ok:
        print("Handing over to RunPod Serverless SDK...", flush=True)
        runpod.serverless.start({"handler": process_job})
    else:
        print("FATAL: ComfyUI failed to initialize.", flush=True)
