import os
import json
import tempfile
from fastapi import FastAPI, File, UploadFile, Form
from pydantic import BaseModel
import uvicorn
from openai import OpenAI
import time

# 把 cuDNN 8 DLL 目录加到 PATH（pip 安装的 nvidia-cudnn-cu12 不会自动加）
try:
    import nvidia.cudnn
    _cudnn_bin = os.path.join(os.path.dirname(nvidia.cudnn.__file__), "bin")
    if os.path.isdir(_cudnn_bin):
        os.environ["PATH"] = _cudnn_bin + os.pathsep + os.environ.get("PATH", "")
except ImportError:
    pass

from faster_whisper import WhisperModel
from deep_translator import GoogleTranslator

# DeepSeek API 需要代理（国内环境）
os.environ["HTTP_PROXY"] = "http://127.0.0.1:7890"
os.environ["HTTPS_PROXY"] = "http://127.0.0.1:7890"

# ⚠️ PLACE YOUR DEEPSEEK API KEY HERE
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY", "your-api-key-here")

client = OpenAI(api_key=DEEPSEEK_API_KEY, base_url="https://api.deepseek.com")

# ── faster-whisper: 本地 STT 引擎 ──
print("⏳ 正在加载 Whisper small 模型...")
try:
    whisper_model = WhisperModel("small", device="cuda", compute_type="float16")
    print("✅ Whisper 模型加载完成 (GPU)")
except Exception as e:
    print(f"⚠️ GPU 加载失败 ({e})，回退到 CPU...")
    whisper_model = WhisperModel("small", device="cpu", compute_type="int8")
    print("✅ Whisper 模型加载完成 (CPU)")


app = FastAPI(title="SimulNote DeepSeek Backend")

class SummarizeRequest(BaseModel):
    text: str

class TranslateRequest(BaseModel):
    text: str
    direction: str = "EN_ZH"

# ──────────── 全局状态 ────────────
prev_stt_text = ""        # 上一次 STT 文本，作为 Whisper 的 initial_prompt 提供上下文


@app.post("/reset")
async def reset_context():
    global prev_stt_text
    prev_stt_text = ""
    return {"status": "ok"}


@app.post("/transcribe")
async def transcribe(audio: UploadFile = File(...), direction: str = Form("EN_ZH")):
    """STT 当前切片，用上次结果作为 initial_prompt 保持上下文连贯"""
    global prev_stt_text

    audio_bytes = await audio.read()

    # ── STT via faster-whisper ──
    stt_lang = "en" if direction == "EN_ZH" else "zh"
    try:
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp.write(audio_bytes)
            tmp_path = tmp.name

        t0 = time.time()
        # initial_prompt: 把上一次的识别结果传给 Whisper，帮助它保持上下文连贯
        # 这比滑动窗口 + 去重更简单可靠
        segments_iter, info = whisper_model.transcribe(
            tmp_path, language=stt_lang, beam_size=5,
            vad_filter=True,
            initial_prompt=prev_stt_text if prev_stt_text else None,
        )
        all_segments = list(segments_iter)
        os.unlink(tmp_path)

        elapsed = time.time() - t0
        source_text = " ".join([seg.text for seg in all_segments]).strip()

        if source_text:
            prev_stt_text = source_text  # 保存用于下次上下文
            print(f"✅ STT 耗时: {elapsed:.2f}s (文本: {source_text})")
        else:
            print(f"❌ STT: 没听清 ({elapsed:.2f}s)")

    except Exception as e:
        print(f"❌ STT 异常: {e}")
        source_text = ""
        try:
            os.unlink(tmp_path)
        except:
            pass

    if not source_text:
        return {"transcription": ""}

    return {"transcription": source_text}


@app.post("/translate")
async def translate(req: TranslateRequest):
    """实时翻译用 Google Translate"""
    clean_text = req.text.strip()
    clean_text = clean_text.replace("...", " ").replace("..", " ").strip()
    clean_text = " ".join(clean_text.split())

    if not clean_text or len(clean_text) < 2:
        return {"translation": ""}

    src_lang = "en" if req.direction == "EN_ZH" else "zh-CN"
    tgt_lang = "zh-CN" if req.direction == "EN_ZH" else "en"

    t1 = time.time()
    try:
        translation = GoogleTranslator(source=src_lang, target=tgt_lang).translate(clean_text)
        if not translation:
            translation = clean_text
        print(f"✅ 翻译: {time.time() - t1:.2f}s  [源]: {clean_text}  [译]: {translation}")
    except Exception as e:
        translation = clean_text
        print(f"⚠️ 翻译失败，返回原文: {e}")

    return {"translation": translation}


@app.post("/summarize")
async def summarize(req: SummarizeRequest):
    if not req.text.strip():
        return {"summary": {}}

    try:
        system_prompt = """You are a professional meeting/lecture summarizer.
Analyze the following transcript and produce a structured JSON summary with exactly these fields:

{
  "topic": "A one-line description of the main topic discussed",
  "key_points": ["Point 1", "Point 2", ...],
  "action_items": ["Action 1", "Action 2", ...],
  "decisions": ["Decision 1", ...],
  "brief_summary": "A 2-3 sentence executive summary"
}

Rules:
- If a section has no content, use an empty array []
- key_points should have 3-7 items
- Be concise and specific
- Output ONLY valid JSON, no markdown, no explanation"""

        response = client.chat.completions.create(
            model="deepseek-chat",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": req.text}
            ],
            temperature=0.3,
        )
        raw = response.choices[0].message.content.strip()
        try:
            summary_data = json.loads(raw)
        except json.JSONDecodeError:
            if "```json" in raw:
                raw = raw.split("```json")[1].split("```")[0].strip()
            elif "```" in raw:
                raw = raw.split("```")[1].split("```")[0].strip()
            try:
                summary_data = json.loads(raw)
            except:
                summary_data = {"brief_summary": raw, "topic": "", "key_points": [], "action_items": [], "decisions": []}

    except Exception as e:
        summary_data = {"brief_summary": f"[DeepSeek API Error: {e}]", "topic": "", "key_points": [], "action_items": [], "decisions": []}

    return {"summary": summary_data}


if __name__ == "__main__":
    print("🚀 Starting SimulNote DeepSeek Backend on http://localhost:8000")
    uvicorn.run(app, host="0.0.0.0", port=8000)
