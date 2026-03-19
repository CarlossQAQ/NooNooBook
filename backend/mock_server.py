from fastapi import FastAPI, File, UploadFile, Form
from pydantic import BaseModel
import uvicorn
import random
import time

app = FastAPI(title="SimulNote Mock AI Server")

class SummarizeRequest(BaseModel):
    text: str

# A mock list of sentences to simulate a continuous lecture
MOCK_SENTENCES = [
    "Welcome to today's lecture. Today we will discuss Eukaryotic cells.",
    "The eukaryotic cell is defined by the presence of a nucleus.",
    "This nucleus stores the genetic information or DNA of the cell.",
    "Mitochondria are often referred to as the powerhouse of the cell,",
    "because they break down glucose to produce ATP.",
    "Ribosomes are responsible for protein synthesis.",
    "The cell membrane forms the boundary between the cell and its environment.",
    "Any questions so far before we move on to Plant Cells?",
    "Okay, moving on. Plant cells have a rigid cell wall.",
    "They also contain chloroplasts, which conduct photosynthesis."
]

current_index = 0

@app.post("/transcribe")
async def transcribe_audio(audio: UploadFile = File(...), direction: str = Form("EN_ZH")):
    global current_index
    
    # Simulate processing time
    time.sleep(random.uniform(0.5, 1.2))
    
    # Toggle behavior based on direction
    if direction == "ZH_EN":
        src_text = "这是模拟中文源文本。"
        tgt_text = "This is a simulated English translation."
    else:
        src_text = MOCK_SENTENCES[current_index % len(MOCK_SENTENCES)]
        tgt_text = "（生僻字过滤测试）生物大分子功能翻译模拟"
        current_index += 1
    
    return {
        "transcription": src_text,
        "translation": tgt_text
    }

@app.post("/summarize")
async def summarize_text(req: SummarizeRequest):
    time.sleep(random.uniform(1.0, 2.0))
    summary = f"""**Simulated AI Summary**

- The user stopped recording after speaking {len(req.text)} characters.
- A key discussion topic was cellular biology and eukaryotes.
- The model successfully extracted meaning from the context.

*Note: In production this would hit ChatGPT or another LLM.*"""
    return {"summary": summary}

if __name__ == "__main__":
    print("🚀 Starting SimulNote Mock Backend on http://localhost:8000")
    uvicorn.run(app, host="0.0.0.0", port=8000)
